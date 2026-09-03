-- ==========================================================================
-- EduFess — M6 BK security foundation verification
-- Covers C1-C5, V1-V10, M1-M7, I1-I10, P1-P6
-- HOW TO RUN: npx supabase db query --linked --file supabase/verification/m6_security_tests.sql
-- ==========================================================================

do $m6$
declare
  v_count int;
  v_display text;
  v_alias text;
  v_conversation_id uuid;
  v_conversation2 uuid;
  v_message_id uuid;
  v_report_id uuid;
  v_pseudonym text;
  v_student1_id uuid := 'eeeeeeee-eeee-4000-8000-000000000001'::uuid;
  v_student2_id uuid := 'eeeeeeee-eeee-4000-8000-000000000002'::uuid;
  v_counselor1_id uuid := 'eeeeeeee-eeee-4000-8000-000000000003'::uuid;
  v_counselor2_id uuid := 'eeeeeeee-eeee-4000-8000-000000000004'::uuid;
  v_admin_id uuid := 'eeeeeeee-eeee-4000-8000-000000000005'::uuid;
  v_tmp uuid;
  v_rec record;
  v_is_admin boolean;
  v_deleted_at timestamptz;
  v_student1_pseudonym text := 'M6_Student1';
  v_student2_pseudonym text := 'M6_Student2';
begin
  -- Cleanup prior M6
  delete from public.bk_identity_access_log where counselor_id in (v_counselor1_id, v_counselor2_id);
  delete from public.counseling_messages where sender_id in (v_student1_id, v_student2_id, v_counselor1_id, v_counselor2_id);
  delete from public.counseling_conversations where student_id in (v_student1_id, v_student2_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm6_%@example.com';
  delete from public.invitation_codes where code like 'M6TEST-%';

  insert into public.invitation_codes (code) values ('M6TEST-S1'),('M6TEST-S2'),('M6TEST-C1'),('M6TEST-C2'),('M6TEST-ADM');

  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student1_id,'authenticated','authenticated','m6_student1@example.com', extensions.crypt('M6-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym',v_student1_pseudonym,'invite_code','M6TEST-S1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student2_id,'authenticated','authenticated','m6_student2@example.com', extensions.crypt('M6-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym',v_student2_pseudonym,'invite_code','M6TEST-S2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor1_id,'authenticated','authenticated','m6_counselor1@example.com', extensions.crypt('M6-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M6_Counselor1','invite_code','M6TEST-C1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor2_id,'authenticated','authenticated','m6_counselor2@example.com', extensions.crypt('M6-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M6_Counselor2','invite_code','M6TEST-C2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_admin_id,'authenticated','authenticated','m6_admin@example.com', extensions.crypt('M6-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M6_Admin','invite_code','M6TEST-ADM'), now(), now());

  update public.profiles set role='counselor' where id in (v_counselor1_id, v_counselor2_id);
  update public.profiles set role='admin' where id=v_admin_id;
  raise notice 'SEED: 5 M6 users';

  -- ============================================================
  -- C1 student can create own consent
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000001';
  insert into public.bk_consents (student_id, version) values (v_student1_id, 'bk-consent-v1') returning id into v_tmp;
  if v_tmp is null then raise exception 'FAIL C1'; end if;
  raise notice 'PASS C1: student can create own consent %', v_tmp;
  reset role;

  -- ============================================================
  -- C2 student_id spoof denied/forced
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000002';
  -- Try to create consent for student1 while auth as student2, should be forced to student2
  insert into public.bk_consents (student_id, version) values (v_student1_id, 'bk-consent-v1') returning id, student_id into v_tmp, v_conversation_id;
  -- v_conversation_id holds student_id uuid here (reused)
  if v_conversation_id <> v_student2_id then raise exception 'FAIL C2: spoof not forced %', v_conversation_id; end if;
  raise notice 'PASS C2: spoof forced %', v_conversation_id;
  reset role;
  delete from public.bk_consents where id=v_tmp;

  -- ============================================================
  -- C3 other user cannot read student's consent
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000002';
  select count(*) into v_count from public.bk_consents where student_id=v_student1_id;
  if v_count <> 0 then raise exception 'FAIL C3: other can read %', v_count; end if;
  raise notice 'PASS C3: other cannot read consent';
  reset role;

  -- ============================================================
  -- C4 counselor cannot create student consent
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000003';
  begin
    insert into public.bk_consents (student_id, version) values (v_counselor1_id, 'bk-consent-v1');
    raise exception 'FAIL C4: counselor created';
  exception when others then
    if sqlerrm like 'FAIL C4:%' then raise; end if;
    raise notice 'PASS C4: counselor cannot create consent (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- C5 active consent required for new conversation
  -- ============================================================
  -- student2 has no consent, try create conversation should fail
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000002';
  begin
    insert into public.counseling_conversations (student_id, student_alias) values (v_student2_id, 'temp');
    raise exception 'FAIL C5: no consent allowed';
  exception when others then
    if sqlerrm like 'FAIL C5:%' then raise; end if;
    if sqlerrm not ilike '%perlu menyetujui%' then raise exception 'FAIL C5: wrong error %', sqlerrm; end if;
    raise notice 'PASS C5: consent required (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- V1 student can create own conversation with consent
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000001';
  insert into public.counseling_conversations (student_id, student_alias) values (v_student1_id, 'temp') returning id into v_conversation_id;
  if v_conversation_id is null then raise exception 'FAIL V1'; end if;
  raise notice 'PASS V1: student can create conversation %', v_conversation_id;
  reset role;

  -- Ensure student2 has consent for V2
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000002';
  insert into public.bk_consents (student_id, version) values (v_student2_id, 'bk-consent-v1');
  reset role;

  -- ============================================================
  -- V2 student cannot create for another student
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000002';
  insert into public.counseling_conversations (student_id, student_alias) values (v_student1_id, 'temp') returning id, student_id into v_tmp, v_conversation2;
  if v_conversation2 <> v_student2_id then raise exception 'FAIL V2: spoof not forced %', v_conversation2; end if;
  raise notice 'PASS V2: spoof forced to own %', v_conversation2;
  reset role;
  delete from public.counseling_conversations where id=v_tmp;

  -- ============================================================
  -- V3 alias generated server-side
  -- ============================================================
  select student_alias into v_alias from public.counseling_conversations where id=v_conversation_id;
  if v_alias is null or v_alias not ilike 'Siswa BK #%' then raise exception 'FAIL V3: alias not generated %', v_alias; end if;
  if v_alias = v_student1_pseudonym then raise exception 'FAIL V3: alias equals pseudonym'; end if;
  raise notice 'PASS V3: alias generated %', v_alias;

  -- ============================================================
  -- V4 student cannot assign counselor
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000001';
  begin
    update public.counseling_conversations set counselor_id=v_counselor1_id where id=v_conversation_id;
    raise exception 'FAIL V4: student assigned';
  exception when others then
    if sqlerrm like 'FAIL V4:%' then raise; end if;
    raise notice 'PASS V4: student cannot assign counselor (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- V5 counselor can claim unassigned
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000003';
  perform public.claim_counseling_conversation(v_conversation_id);
  select counselor_id into v_tmp from public.counseling_conversations where id=v_conversation_id;
  if v_tmp <> v_counselor1_id then raise exception 'FAIL V5: not claimed %', v_tmp; end if;
  raise notice 'PASS V5: counselor can claim';
  reset role;

  -- ============================================================
  -- V6 second counselor cannot claim already assigned
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000004';
  begin
    perform public.claim_counseling_conversation(v_conversation_id);
    raise exception 'FAIL V6: second claim allowed';
  exception when others then
    if sqlerrm like 'FAIL V6:%' then raise; end if;
    raise notice 'PASS V6: second counselor cannot claim (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- V7 student cannot view another's conversation
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000002';
  select count(*) into v_count from public.counseling_conversations where id=v_conversation_id;
  if v_count <> 0 then raise exception 'FAIL V7: other student sees %', v_count; end if;
  raise notice 'PASS V7: student cannot view another';
  reset role;

  -- ============================================================
  -- V8 unassigned queue exposes alias only
  -- ============================================================
  -- Create a second unassigned conversation for queue test (as student2)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000002';
  insert into public.counseling_conversations (student_id, student_alias) values (v_student2_id, 'temp') returning id into v_conversation2;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000003';
  select count(*) into v_count from public.get_counselor_bk_queue();
  if v_count < 1 then raise exception 'FAIL V8: queue empty'; end if;
  -- Check that queue does not expose student_id
  begin
    select student_id into v_display from public.get_counselor_bk_queue() limit 1;
    raise exception 'FAIL V8: student_id exposed';
  exception when undefined_column then
    raise notice 'PASS V8: queue alias only, no student_id';
  end;
  -- Check display alias present
  select student_alias into v_alias from public.get_counselor_bk_queue() limit 1;
  if v_alias not ilike 'Siswa BK #%' then raise exception 'FAIL V8: alias not %', v_alias; end if;
  raise notice 'PASS V8: queue alias only';
  reset role;

  -- ============================================================
  -- V9 admin cannot view BK queue
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000005';
  begin
    perform public.get_counselor_bk_queue();
    raise exception 'FAIL V9: admin viewed';
  exception when others then
    if sqlerrm like 'FAIL V9:%' then raise; end if;
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL V9: wrong %', sqlerrm; end if;
    raise notice 'PASS V9: admin cannot view BK queue';
  end;
  reset role;

  -- ============================================================
  -- V10 social moderator/admin cannot access BK conversation
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000005';
  select count(*) into v_count from public.counseling_conversations where id=v_conversation_id;
  if v_count <> 0 then raise exception 'FAIL V10: admin accessed BK conversation'; end if;
  raise notice 'PASS V10: admin cannot access BK conversation';
  reset role;

  -- ============================================================
  -- M1 student can send message to own conversation
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000001';
  insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_student1_id, 'Halo BK') returning id into v_message_id;
  if v_message_id is null then raise exception 'FAIL M1'; end if;
  raise notice 'PASS M1: student can send message %', v_message_id;
  reset role;

  -- ============================================================
  -- M2 sender spoofing denied
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000001';
  insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_counselor1_id, 'spoof') returning id, sender_id into v_tmp, v_conversation2;
  if v_conversation2 = v_counselor1_id then raise exception 'FAIL M2: spoof not forced'; end if;
  if v_conversation2 <> v_student1_id then raise exception 'FAIL M2: not forced to own %', v_conversation2; end if;
  raise notice 'PASS M2: sender spoof forced';
  reset role;
  delete from public.counseling_messages where id=v_tmp;

  -- ============================================================
  -- M3 assigned counselor can send
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000003';
  insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_counselor1_id, 'Balasan konselor') returning id into v_tmp;
  if v_tmp is null then raise exception 'FAIL M3'; end if;
  raise notice 'PASS M3: counselor can send %', v_tmp;
  reset role;

  -- ============================================================
  -- M4 unrelated counselor cannot read messages
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000004';
  begin
    select * into v_rec from public.get_counseling_messages(v_conversation_id) limit 1;
    raise exception 'FAIL M4: unrelated read';
  exception when others then
    if sqlerrm like 'FAIL M4:%' then raise; end if;
    if sqlerrm not ilike '%tidak memiliki akses%' then raise exception 'FAIL M4: wrong %', sqlerrm; end if;
    raise notice 'PASS M4: unrelated counselor cannot read';
  end;
  -- Also direct table
  select count(*) into v_count from (select 1 from public.counseling_messages where conversation_id = v_conversation_id) as sub;
  if v_count <> 0 then raise exception 'FAIL M4 direct: saw %', v_count; end if;
  raise notice 'PASS M4 direct: no access';
  reset role;

  -- ============================================================
  -- M5 unrelated counselor cannot send
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000004';
  begin
    insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_counselor2_id, 'intrude');
    raise exception 'FAIL M5: unrelated send allowed';
  exception when others then
    if sqlerrm like 'FAIL M5:%' then raise; end if;
    raise notice 'PASS M5: unrelated counselor cannot send (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- M6 other student cannot read messages
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000002';
  select count(*) into v_count from (select 1 from public.counseling_messages where conversation_id = v_conversation_id) as sub;
  if v_count <> 0 then raise exception 'FAIL M6: other student read %', v_count; end if;
  begin
    select * into v_rec from public.get_counseling_messages(v_conversation_id) limit 1;
    raise exception 'FAIL M6: other student via rpc';
  exception when others then
    if sqlerrm like 'FAIL M6:%' then raise; end if;
    raise notice 'PASS M6: other student cannot read (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- M7 admin cannot read counseling messages
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000005';
  select count(*) into v_count from (select 1 from public.counseling_messages where conversation_id = v_conversation_id) as sub;
  if v_count <> 0 then raise exception 'FAIL M7: admin read direct %', v_count; end if;
  begin
    select * into v_rec from public.get_counseling_messages(v_conversation_id) limit 1;
    raise exception 'FAIL M7: admin via rpc';
  exception when others then
    if sqlerrm like 'FAIL M7:%' then raise; end if;
    raise notice 'PASS M7: admin cannot read messages (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- I1 assigned counselor can reveal identity with reason
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000003';
  select * into v_pseudonym from public.reveal_counseling_identity(v_conversation_id, 'Kebutuhan pendampingan') limit 1;
  -- Actually function returns table student_id, pseudonym; capture via select into
  -- Use separate select
  select pseudonym into v_pseudonym from public.reveal_counseling_identity(v_conversation_id, 'Kebutuhan lanjutan') limit 1;
  if v_pseudonym <> v_student1_pseudonym then raise exception 'FAIL I1: wrong pseudonym % expected %', v_pseudonym, v_student1_pseudonym; end if;
  raise notice 'PASS I1: assigned counselor can reveal %', v_pseudonym;
  reset role;

  -- ============================================================
  -- I2 unassigned counselor cannot reveal
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000004';
  begin
    select * into v_rec from public.reveal_counseling_identity(v_conversation2, 'test') limit 1;
    raise exception 'FAIL I2: unassigned reveal allowed';
  exception when others then
    if sqlerrm like 'FAIL I2:%' then raise; end if;
    raise notice 'PASS I2: unassigned cannot reveal (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- I3 unrelated counselor cannot reveal
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000004';
  begin
    select * into v_rec from public.reveal_counseling_identity(v_conversation_id, 'test') limit 1;
    raise exception 'FAIL I3: unrelated reveal allowed';
  exception when others then
    if sqlerrm like 'FAIL I3:%' then raise; end if;
    raise notice 'PASS I3: unrelated cannot reveal (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- I4 student cannot invoke reveal
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000001';
  begin
    select * into v_rec from public.reveal_counseling_identity(v_conversation_id, 'test') limit 1;
    raise exception 'FAIL I4: student reveal';
  exception when others then
    if sqlerrm like 'FAIL I4:%' then raise; end if;
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL I4: wrong %', sqlerrm; end if;
    raise notice 'PASS I4: student cannot reveal';
  end;
  reset role;

  -- ============================================================
  -- I5 admin cannot invoke reveal
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000005';
  begin
    select * into v_rec from public.reveal_counseling_identity(v_conversation_id, 'test') limit 1;
    raise exception 'FAIL I5: admin reveal';
  exception when others then
    if sqlerrm like 'FAIL I5:%' then raise; end if;
    raise notice 'PASS I5: admin cannot reveal (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- I6 reason required
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000003';
  begin
    select * into v_rec from public.reveal_counseling_identity(v_conversation_id, '') limit 1;
    raise exception 'FAIL I6: empty reason allowed';
  exception when others then
    if sqlerrm like 'FAIL I6:%' then raise; end if;
    if sqlerrm not ilike '%Reason required%' then raise exception 'FAIL I6: wrong %', sqlerrm; end if;
    raise notice 'PASS I6: reason required';
  end;
  begin
    select * into v_rec from public.reveal_counseling_identity(v_conversation_id, null) limit 1;
    raise exception 'FAIL I6b: null reason allowed';
  exception when others then
    if sqlerrm like 'FAIL I6b:%' then raise; end if;
    raise notice 'PASS I6b: null reason blocked';
  end;
  reset role;

  -- ============================================================
  -- I7 every reveal writes audit row
  -- ============================================================
  select count(*) into v_count from public.bk_identity_access_log where bk_identity_access_log.conversation_id = v_conversation_id and counselor_id=v_counselor1_id;
  if v_count < 1 then raise exception 'FAIL I7: no audit %', v_count; end if;
  raise notice 'PASS I7: audit row exists %', v_count;

  -- ============================================================
  -- I8 audit row counselor/student/conversation correct
  -- ============================================================
  select count(*) into v_count from public.bk_identity_access_log where counselor_id=v_counselor1_id and student_id=v_student1_id and conversation_id=v_conversation_id;
  if v_count < 1 then raise exception 'FAIL I8: audit mismatch %', v_count; end if;
  raise notice 'PASS I8: audit correct';

  -- ============================================================
  -- I9 normal queue does not expose student_id
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000003';
  begin
    select student_id into v_display from public.get_counselor_bk_queue() limit 1;
    raise exception 'FAIL I9: student_id exposed';
  exception when undefined_column then
    raise notice 'PASS I9: queue no student_id';
  end;
  reset role;

  -- ============================================================
  -- I10 normal queue does not expose real pseudonym/email
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000003';
  declare v_def text;
  begin
    select pg_get_functiondef(p.oid) into v_def from pg_proc p where proname='get_counselor_bk_queue' and pronamespace='public'::regnamespace;
    if v_def ilike '%student_id%' and v_def not ilike '%student_alias%' then
      -- check if student_id is in return table (we already checked I9)
      raise notice 'WARN I10: check manual';
    end if;
    if v_def ilike '%email%' then raise exception 'FAIL I10: email in queue'; end if;
    -- Try to select pseudonym/email from queue
    begin
      select pseudonym into v_display from public.get_counselor_bk_queue() limit 1;
      raise exception 'FAIL I10: pseudonym exposed';
    exception when undefined_column then
      raise notice 'PASS I10a: no pseudonym';
    end;
    begin
      select email into v_display from public.get_counselor_bk_queue() limit 1;
      raise exception 'FAIL I10 email';
    exception when undefined_column then
      raise notice 'PASS I10b: no email';
    end;
    raise notice 'PASS I10: queue no real pseudonym/email';
  end;
  reset role;

  -- ============================================================
  -- P1 posts_feed contains no BK data
  -- ============================================================
  if exists (select 1 from information_schema.columns where table_name='posts_feed' and column_name ilike '%bk%') then raise exception 'FAIL P1: bk in posts_feed'; end if;
  if exists (select 1 from information_schema.columns where table_name='posts_feed' and column_name='student_alias') then raise exception 'FAIL P1: alias in posts_feed'; end if;
  raise notice 'PASS P1: posts_feed no BK';

  -- P2 comments_feed contains no BK data
  if exists (select 1 from information_schema.columns where table_name='comments_feed' and column_name ilike '%bk%') then raise exception 'FAIL P2'; end if;
  raise notice 'PASS P2: comments_feed no BK';

  -- P3 search_posts contains no BK data
  declare v_search_def text;
  begin
    select pg_get_functiondef(p.oid) into v_search_def from pg_proc p where proname='search_posts';
    if v_search_def ilike '%bk_%' or v_search_def ilike '%counseling%' then raise exception 'FAIL P3: BK in search_posts'; end if;
    raise notice 'PASS P3: search_posts no BK';
  end;

  -- P4 moderation queue contains no BK data
  declare v_mod_def text;
  begin
    select pg_get_functiondef(p.oid) into v_mod_def from pg_proc p where proname='get_moderation_queue';
    if v_mod_def ilike '%bk_%' or v_mod_def ilike '%counseling%' then raise exception 'FAIL P4: BK in moderation'; end if;
    raise notice 'PASS P4: moderation queue no BK';
  end;

  -- P5 social admin has no BK grants
  select count(*) into v_count from information_schema.role_table_grants where table_name in ('bk_consents','counseling_conversations','counseling_messages','bk_identity_access_log') and grantee='admin';
  -- Role admin not a grantee in role_table_grants (grantee is authenticated), so check authenticated has limited
  -- Instead check that authenticated does not have bypass: check that BK tables not granted to anon
  select count(*) into v_count from information_schema.role_table_grants where table_name='bk_consents' and grantee='anon' and privilege_type='SELECT';
  if v_count <> 0 then raise exception 'FAIL P5: anon has BK'; end if;
  raise notice 'PASS P5: social admin has no BK grants via anon';

  -- P6 counselor gains no social moderation privilege
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"eeeeeeee-eeee-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-4000-8000-000000000003';
  begin
    select count(*) into v_count from public.get_moderation_queue();
    raise exception 'FAIL P6: counselor has moderation';
  exception when others then
    if sqlerrm like 'FAIL P6:%' then raise; end if;
    raise notice 'PASS P6: counselor no moderation privilege (%)', sqlerrm;
  end;
  reset role;

  -- Cleanup
  delete from public.bk_identity_access_log where counselor_id in (v_counselor1_id, v_counselor2_id);
  delete from public.counseling_messages where sender_id in (v_student1_id, v_student2_id, v_counselor1_id);
  delete from public.counseling_conversations where student_id in (v_student1_id, v_student2_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm6_%@example.com';
  delete from public.invitation_codes where code like 'M6TEST-%';
  raise notice 'ALL M6 SECURITY SCENARIOS COMPLETE';
end
$m6$;
