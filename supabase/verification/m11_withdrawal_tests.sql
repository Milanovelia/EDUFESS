-- ==========================================================================
-- EduFess — M11 reporter withdrawal verification (companion to
-- m11_security_tests + m11_closure_feedback_tests)
-- Covers W1-W17: reporter-only pending withdrawal, audit retention,
-- role/state denials, queue/history exclusion, resubmit-allowed, and
-- claim/withdraw race safety.
-- HOW TO RUN: npx supabase db query --linked --file supabase/verification/m11_withdrawal_tests.sql
-- Requires migration 20260831000020 applied.
-- ==========================================================================

do $m11w$
declare
  v_count int;
  v_concern_id uuid;
  v_student1_id uuid := 'dddddddd-dddd-4000-8000-000000000001'::uuid;
  v_student2_id uuid := 'dddddddd-dddd-4000-8000-000000000002'::uuid;
  v_counselor1_id uuid := 'dddddddd-dddd-4000-8000-000000000004'::uuid;
  v_admin_id uuid := 'dddddddd-dddd-4000-8000-000000000006'::uuid;
  v_rec record;
begin
  -- Seed (isolated M11W users)
  delete from public.bk_peer_concerns where reporter_id in (v_student1_id, v_student2_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm11w_%@example.com';
  delete from public.invitation_codes where code like 'M11WTEST-%';
  insert into public.invitation_codes (code) values ('M11WTEST-S1'),('M11WTEST-S2'),('M11WTEST-C1'),('M11WTEST-ADM');
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student1_id,'authenticated','authenticated','m11w_student1@example.com', extensions.crypt('M11W-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M11W_Student1','invite_code','M11WTEST-S1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student2_id,'authenticated','authenticated','m11w_student2@example.com', extensions.crypt('M11W-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M11W_Student2','invite_code','M11WTEST-S2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor1_id,'authenticated','authenticated','m11w_counselor1@example.com', extensions.crypt('M11W-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M11W_Counselor1','invite_code','M11WTEST-C1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_admin_id,'authenticated','authenticated','m11w_admin@example.com', extensions.crypt('M11W-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M11W_Admin','invite_code','M11WTEST-ADM'), now(), now());
  update public.profiles set role='counselor' where id = v_counselor1_id;
  update public.profiles set role='admin' where id = v_admin_id;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  insert into public.bk_consents (student_id, version) values (v_student1_id, 'bk-consent-v1');
  reset role;
  raise notice 'SEED M11W users';

  -- W1 reporter can withdraw own pending concern
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  select public.submit_bk_peer_concern(v_student2_id, 'emotional', 'W test') into v_concern_id;
  perform public.withdraw_bk_peer_concern(v_concern_id);
  reset role;
  raise notice 'PASS W1: reporter withdrew own pending concern';

  -- W2/W3/W4/W5 audit retention: row exists, status withdrawn, withdrawn_at set, handler fields null
  select * into v_rec from public.bk_peer_concerns where id = v_concern_id;
  if v_rec.status <> 'withdrawn' then raise exception 'FAIL W3: status %', v_rec.status; end if;
  if v_rec.withdrawn_at is null then raise exception 'FAIL W4: withdrawn_at null'; end if;
  if v_rec.handled_by is not null or v_rec.handled_at is not null or v_rec.closed_at is not null then
    raise exception 'FAIL W5: handler fields not null';
  end if;
  if v_rec.resolution_note is not null or v_rec.reporter_response is not null then
    raise exception 'FAIL W5: notes not null';
  end if;
  raise notice 'PASS W2/W3/W4/W5: row retained, withdrawn, timestamps clean';

  -- W6 another student cannot withdraw it (fresh row first)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  select public.submit_bk_peer_concern(v_student2_id, 'social', 'W6') into v_concern_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  begin
    perform public.withdraw_bk_peer_concern(v_concern_id);
    raise exception 'FAIL W6: other student withdrew';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL W6: wrong %', sqlerrm; end if;
    raise notice 'PASS W6: other student denied';
  end;
  reset role;

  -- W7 target cannot withdraw it (target is student2)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  begin
    perform public.withdraw_bk_peer_concern(v_concern_id);
    raise exception 'FAIL W7: target withdrew';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL W7: wrong %', sqlerrm; end if;
    raise notice 'PASS W7: target denied';
  end;
  reset role;

  -- W8 counselor cannot withdraw it
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000004';
  begin
    perform public.withdraw_bk_peer_concern(v_concern_id);
    raise exception 'FAIL W8: counselor withdrew';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL W8: wrong %', sqlerrm; end if;
    raise notice 'PASS W8: counselor denied';
  end;
  reset role;

  -- W9 admin cannot withdraw it
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000006","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000006';
  begin
    perform public.withdraw_bk_peer_concern(v_concern_id);
    raise exception 'FAIL W9: admin withdrew';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL W9: wrong %', sqlerrm; end if;
    raise notice 'PASS W9: admin denied';
  end;
  reset role;

  -- W10 reviewing cannot be withdrawn (claim then withdraw)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000004';
  perform public.claim_bk_peer_concern(v_concern_id);
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  begin
    perform public.withdraw_bk_peer_concern(v_concern_id);
    raise exception 'FAIL W10: reviewing withdrawn';
  exception when others then
    if sqlerrm not ilike '%sudah mulai ditangani%' then raise exception 'FAIL W10: wrong %', sqlerrm; end if;
    raise notice 'PASS W10: reviewing protected';
  end;
  reset role;

  -- W11 resolved cannot be withdrawn
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000004';
  perform public.resolve_bk_peer_concern(v_concern_id, null, null);
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  begin
    perform public.withdraw_bk_peer_concern(v_concern_id);
    raise exception 'FAIL W11: resolved withdrawn';
  exception when others then
    if sqlerrm not ilike '%sudah selesai%' then raise exception 'FAIL W11: wrong %', sqlerrm; end if;
    raise notice 'PASS W11: resolved protected';
  end;
  reset role;

  -- W12 dismissed cannot be withdrawn (fresh row through dismiss path)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  select public.submit_bk_peer_concern(v_student2_id, 'family', 'W12') into v_concern_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000004';
  perform public.claim_bk_peer_concern(v_concern_id);
  perform public.dismiss_bk_peer_concern(v_concern_id, null, null);
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  begin
    perform public.withdraw_bk_peer_concern(v_concern_id);
    raise exception 'FAIL W12: dismissed withdrawn';
  exception when others then
    if sqlerrm not ilike '%sudah selesai%' then raise exception 'FAIL W12: wrong %', sqlerrm; end if;
    raise notice 'PASS W12: dismissed protected';
  end;
  reset role;

  -- W13 counselor queue excludes withdrawn
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000004';
  select count(*) into v_count from public.get_counselor_peer_concern_queue() where status = 'withdrawn';
  if v_count <> 0 then raise exception 'FAIL W13: withdrawn in queue %', v_count; end if;
  raise notice 'PASS W13: queue excludes withdrawn';
  reset role;

  -- W14 student history includes own withdrawn concern with withdrawn_at
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  select public.submit_bk_peer_concern(v_student2_id, 'other', 'W14') into v_concern_id;
  perform public.withdraw_bk_peer_concern(v_concern_id);
  select count(*) into v_count from public.get_student_peer_concerns() where concern_id = v_concern_id and status = 'withdrawn' and withdrawn_at is not null;
  if v_count <> 1 then raise exception 'FAIL W14: history missing %', v_count; end if;
  raise notice 'PASS W14: history shows withdrawn + withdrawn_at';
  reset role;

  -- W15 withdrawn permits a later new report to the same target
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  select public.submit_bk_peer_concern(v_student2_id, 'bullying', 'W15 resubmit') into v_concern_id;
  if v_concern_id is null then raise exception 'FAIL W15: resubmit blocked'; end if;
  raise notice 'PASS W15: resubmit after withdrawal allowed';
  reset role;

  -- W16 never-claimed withdrawn concern invisible to counselor detail/history
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  perform public.withdraw_bk_peer_concern(v_concern_id);
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000004';
  begin
    perform public.get_counselor_peer_concern_detail(v_concern_id);
    raise exception 'FAIL W16: detail exposed';
  exception when others then
    if sqlerrm not ilike '%Not assigned counselor%' then raise exception 'FAIL W16: wrong %', sqlerrm; end if;
  end;
  select count(*) into v_count from public.get_counselor_peer_concern_history() where concern_id = v_concern_id;
  if v_count <> 0 then raise exception 'FAIL W16: history exposed %', v_count; end if;
  raise notice 'PASS W16: withdrawn invisible to counselor';
  reset role;

  -- W17 race safety: no row may ever mix withdrawn with handled_by set
  select count(*) into v_count from public.bk_peer_concerns where status = 'withdrawn' and handled_by is not null;
  if v_count <> 0 then raise exception 'FAIL W17: mixed state %', v_count; end if;
  raise notice 'PASS W17: no withdrawn+handled_by mixed state';

  -- Cleanup
  delete from public.bk_peer_concerns where reporter_id in (v_student1_id, v_student2_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm11w_%@example.com';
  delete from public.invitation_codes where code like 'M11WTEST-%';
  raise notice 'DONE M11W withdrawal verification';
end $m11w$;
