-- ==========================================================================
-- EduFess — M11 closure feedback verification (companion to m11_security_tests)
-- Covers reporter_response visibility, resolution_note containment,
-- handled_at/closed_at lifecycle, backfill invariant, length guards,
-- target/admin denial, and old-signature backward compatibility.
-- HOW TO RUN: npx supabase db query --linked --file supabase/verification/m11_closure_feedback_tests.sql
-- Requires migration 20260831000019 applied.
-- ==========================================================================

do $m11c$
declare
  v_count int;
  v_concern_id uuid;
  v_student1_id uuid := 'cccccccc-cccc-4000-8000-000000000001'::uuid;
  v_student2_id uuid := 'cccccccc-cccc-4000-8000-000000000002'::uuid;
  v_counselor1_id uuid := 'cccccccc-cccc-4000-8000-000000000004'::uuid;
  v_admin_id uuid := 'cccccccc-cccc-4000-8000-000000000006'::uuid;
  v_handled_before timestamptz;
  v_closed_at timestamptz;
  v_rec record;
begin
  -- Seed (isolated M11C users)
  delete from public.bk_peer_concerns where reporter_id in (v_student1_id, v_student2_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm11c_%@example.com';
  delete from public.invitation_codes where code like 'M11CTEST-%';
  insert into public.invitation_codes (code) values ('M11CTEST-S1'),('M11CTEST-S2'),('M11CTEST-C1'),('M11CTEST-ADM');
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student1_id,'authenticated','authenticated','m11c_student1@example.com', extensions.crypt('M11C-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M11C_Student1','invite_code','M11CTEST-S1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student2_id,'authenticated','authenticated','m11c_student2@example.com', extensions.crypt('M11C-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M11C_Student2','invite_code','M11CTEST-S2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor1_id,'authenticated','authenticated','m11c_counselor1@example.com', extensions.crypt('M11C-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M11C_Counselor1','invite_code','M11CTEST-C1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_admin_id,'authenticated','authenticated','m11c_admin@example.com', extensions.crypt('M11C-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M11C_Admin','invite_code','M11CTEST-ADM'), now(), now());
  update public.profiles set role='counselor' where id = v_counselor1_id;
  update public.profiles set role='admin' where id = v_admin_id;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  insert into public.bk_consents (student_id, version) values (v_student1_id, 'bk-consent-v1');
  reset role;
  raise notice 'SEED M11C users';

  -- CBC1 claim sets handled_at, closed_at stays null
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  select public.submit_bk_peer_concern(v_student2_id, 'emotional', 'CBC test') into v_concern_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000004';
  perform public.claim_bk_peer_concern(v_concern_id);
  reset role;
  select handled_at into v_handled_before from public.bk_peer_concerns where id = v_concern_id;
  select closed_at into v_closed_at from public.bk_peer_concerns where id = v_concern_id;
  if v_handled_before is null then raise exception 'FAIL CBC1: claim did not set handled_at'; end if;
  if v_closed_at is not null then raise exception 'FAIL CBC1: closed_at set at claim'; end if;
  raise notice 'PASS CBC1: claim sets handled_at, closed_at stays null';

  -- CBC2 resolve sets closed_at and does NOT overwrite handled_at
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000004';
  perform public.resolve_bk_peer_concern(v_concern_id, 'internal note', 'student reply');
  reset role;
  select * into v_rec from public.bk_peer_concerns where id = v_concern_id;
  if v_rec.status <> 'resolved' then raise exception 'FAIL CBC2: status %', v_rec.status; end if;
  if v_rec.closed_at is null then raise exception 'FAIL CBC2: closed_at null'; end if;
  if v_rec.handled_at is distinct from v_handled_before then raise exception 'FAIL CBC2: handled_at overwritten'; end if;
  if v_rec.resolution_note <> 'internal note' then raise exception 'FAIL CBC2: note lost'; end if;
  if v_rec.reporter_response <> 'student reply' then raise exception 'FAIL CBC2: response lost'; end if;
  raise notice 'PASS CBC2: resolve sets closed_at, keeps handled_at, stores both notes';

  -- CBC3 reporter sees response + closed_at, never the internal note
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  select * into v_rec from public.get_student_peer_concerns() where concern_id = v_concern_id;
  if v_rec.reporter_response <> 'student reply' then raise exception 'FAIL CBC3: response not visible'; end if;
  if v_rec.closed_at is null then raise exception 'FAIL CBC3: closed_at not visible'; end if;
  begin
    perform (select resolution_note from public.get_student_peer_concerns() where concern_id = v_concern_id);
    raise exception 'FAIL CBC3: resolution_note exposed';
  exception when undefined_column then raise notice 'PASS CBC3: response visible, note contained';
  end;
  reset role;

  -- CBC4 counselor detail sees internal note + response + both dates
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000004';
  select * into v_rec from public.get_counselor_peer_concern_detail(v_concern_id);
  if v_rec.resolution_note <> 'internal note' then raise exception 'FAIL CBC4: note hidden from counselor'; end if;
  if v_rec.reporter_response <> 'student reply' then raise exception 'FAIL CBC4: response hidden from counselor'; end if;
  if v_rec.handled_at is null or v_rec.closed_at is null then raise exception 'FAIL CBC4: dates missing'; end if;
  raise notice 'PASS CBC4: counselor sees note, response, handled_at, closed_at';
  reset role;

  -- CBC5 backfill invariant: no closed row may lack closed_at
  select count(*) into v_count from public.bk_peer_concerns where status in ('resolved','dismissed') and closed_at is null;
  if v_count <> 0 then raise exception 'FAIL CBC5: % unbackfilled rows', v_count; end if;
  raise notice 'PASS CBC5: backfill invariant holds';

  -- CBC6 length guards on both note fields
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  select public.submit_bk_peer_concern(v_student2_id, 'social', 'CBC length') into v_concern_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000004';
  perform public.claim_bk_peer_concern(v_concern_id);
  begin
    perform public.resolve_bk_peer_concern(v_concern_id, repeat('x', 2001), null);
    raise exception 'FAIL CBC6: long note allowed';
  exception when others then
    if sqlerrm not ilike '%Note too long%' then raise exception 'FAIL CBC6: wrong %', sqlerrm; end if;
  end;
  begin
    perform public.resolve_bk_peer_concern(v_concern_id, null, repeat('y', 2001));
    raise exception 'FAIL CBC6: long response allowed';
  exception when others then
    if sqlerrm not ilike '%Response too long%' then raise exception 'FAIL CBC6: wrong %', sqlerrm; end if;
  end;
  raise notice 'PASS CBC6: length guards hold';
  reset role;

  -- CBC7 target student cannot read the concern
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000002';
  select count(*) into v_count from public.bk_peer_concerns where target_student_id = v_student2_id;
  if v_count <> 0 then raise exception 'FAIL CBC7: target direct read %', v_count; end if;
  begin
    perform public.get_counselor_peer_concern_detail(v_concern_id);
    raise exception 'FAIL CBC7: target detail read';
  exception when others then
    raise notice 'PASS CBC7: target cannot read detail (%).', sqlerrm;
  end;
  reset role;

  -- CBC8 admin cannot read counselor queue
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000006","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000006';
  begin
    perform public.get_counselor_peer_concern_queue();
    raise exception 'FAIL CBC8: admin queue read';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL CBC8: wrong %', sqlerrm; end if;
    raise notice 'PASS CBC8: admin denied queue';
  end;
  reset role;

  -- CBC9 old two-arg resolve call still works (backward compatibility)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000004';
  perform public.resolve_bk_peer_concern(v_concern_id, 'legacy note');
  reset role;
  select * into v_rec from public.bk_peer_concerns where id = v_concern_id;
  if v_rec.status <> 'resolved' then raise exception 'FAIL CBC9: status %', v_rec.status; end if;
  if v_rec.resolution_note <> 'legacy note' then raise exception 'FAIL CBC9: note lost'; end if;
  if v_rec.reporter_response is not null then raise exception 'FAIL CBC9: response not null'; end if;
  raise notice 'PASS CBC9: two-arg call compatible';

  -- CBC10 dismissed flow stores response + closed_at via dismiss path
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  select public.submit_bk_peer_concern(v_student2_id, 'family', 'CBC dismiss') into v_concern_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000004';
  perform public.claim_bk_peer_concern(v_concern_id);
  perform public.dismiss_bk_peer_concern(v_concern_id, null, 'ditutup ya');
  reset role;
  select * into v_rec from public.bk_peer_concerns where id = v_concern_id;
  if v_rec.status <> 'dismissed' then raise exception 'FAIL CBC10: status %', v_rec.status; end if;
  if v_rec.closed_at is null then raise exception 'FAIL CBC10: closed_at null'; end if;
  if v_rec.reporter_response <> 'ditutup ya' then raise exception 'FAIL CBC10: response lost'; end if;
  raise notice 'PASS CBC10: dismiss flow stores response + closed_at';

  -- Cleanup
  delete from public.bk_peer_concerns where reporter_id in (v_student1_id, v_student2_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm11c_%@example.com';
  delete from public.invitation_codes where code like 'M11CTEST-%';
  raise notice 'DONE M11C closure feedback verification';
end $m11c$;
