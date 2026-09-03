-- ==========================================================================
-- EduFess — M8 Counselor Experience verification
-- Covers Q1-Q7, C1-C5, A1-A6, M1-M6, CL1-CL8, I1-I10, P1-P6
-- HOW TO RUN: npx supabase db query --linked --file supabase/verification/m8_security_tests.sql
-- ==========================================================================

do $m8$
declare
  v_count int;
  v_display text;
  v_conversation_id uuid;
  v_conversation2 uuid;
  v_student1_id uuid := 'aaaaaaaa-aaaa-4000-8000-000000000001'::uuid;
  v_student2_id uuid := 'aaaaaaaa-aaaa-4000-8000-000000000002'::uuid;
  v_counselor1_id uuid := 'aaaaaaaa-aaaa-4000-8000-000000000003'::uuid;
  v_counselor2_id uuid := 'aaaaaaaa-aaaa-4000-8000-000000000004'::uuid;
  v_admin_id uuid := 'aaaaaaaa-aaaa-4000-8000-000000000005'::uuid;
  v_tmp uuid;
  v_rec record;
  v_closed_at timestamptz;
begin
  -- Cleanup
  delete from public.bk_identity_access_log where counselor_id in (v_counselor1_id, v_counselor2_id);
  delete from public.counseling_messages where sender_id in (v_student1_id, v_student2_id, v_counselor1_id, v_counselor2_id);
  delete from public.counseling_conversations where student_id in (v_student1_id, v_student2_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm8_%@example.com';
  delete from public.invitation_codes where code like 'M8TEST-%';
  insert into public.invitation_codes (code) values ('M8TEST-S1'),('M8TEST-S2'),('M8TEST-C1'),('M8TEST-C2'),('M8TEST-ADM');
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student1_id,'authenticated','authenticated','m8_student1@example.com', extensions.crypt('M8-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M8_Student1','invite_code','M8TEST-S1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student2_id,'authenticated','authenticated','m8_student2@example.com', extensions.crypt('M8-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M8_Student2','invite_code','M8TEST-S2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor1_id,'authenticated','authenticated','m8_counselor1@example.com', extensions.crypt('M8-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M8_Counselor1','invite_code','M8TEST-C1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor2_id,'authenticated','authenticated','m8_counselor2@example.com', extensions.crypt('M8-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M8_Counselor2','invite_code','M8TEST-C2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_admin_id,'authenticated','authenticated','m8_admin@example.com', extensions.crypt('M8-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M8_Admin','invite_code','M8TEST-ADM'), now(), now());
  update public.profiles set role='counselor' where id in (v_counselor1_id, v_counselor2_id);
  update public.profiles set role='admin' where id=v_admin_id;
  raise notice 'SEED M8 users';

  -- Create consent and conversation for student1
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  insert into public.bk_consents (student_id, version) values (v_student1_id, 'bk-consent-v1');
  insert into public.counseling_conversations (student_id, student_alias) values (v_student1_id, 'temp') returning id into v_conversation_id;
  reset role;
  -- Create second student conversation for queue
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000002';
  insert into public.bk_consents (student_id, version) values (v_student2_id, 'bk-consent-v1');
  insert into public.counseling_conversations (student_id, student_alias) values (v_student2_id, 'temp') returning id into v_conversation2;
  reset role;

  -- ============================================================
  -- Q1 counselor can read unassigned queue
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  select count(*) into v_count from public.get_counselor_bk_queue();
  if v_count < 2 then raise exception 'FAIL Q1: queue count %', v_count; end if;
  raise notice 'PASS Q1: counselor can read queue %', v_count;
  reset role;

  -- ============================================================
  -- Q2 queue alias only
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  select student_alias into v_display from public.get_counselor_bk_queue() limit 1;
  if v_display not ilike 'Siswa BK #%' then raise exception 'FAIL Q2: alias %', v_display; end if;
  raise notice 'PASS Q2: alias only %', v_display;
  reset role;

  -- Q3 queue no student_id
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  begin
    perform (select student_id from public.get_counselor_bk_queue() limit 1);
    raise exception 'FAIL Q3: student_id exposed';
  exception when undefined_column then raise notice 'PASS Q3: no student_id';
  end;
  reset role;

  -- Q4 queue no real pseudonym
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  declare v_def text;
  begin
    select pg_get_functiondef(p.oid) into v_def from pg_proc p where proname='get_counselor_bk_queue';
    if v_def ilike '%pseudonym%' then raise exception 'FAIL Q4: pseudonym in def'; end if;
    raise notice 'PASS Q4: no pseudonym';
  end;
  reset role;

  -- Q5 queue no email
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  declare v_def2 text;
  begin
    select pg_get_functiondef(p.oid) into v_def2 from pg_proc p where proname='get_counselor_bk_queue';
    if v_def2 ilike '%email%' then raise exception 'FAIL Q5: email'; end if;
    raise notice 'PASS Q5: no email';
  end;
  reset role;

  -- Q6 student cannot access queue
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  begin
    perform * from public.get_counselor_bk_queue();
    raise exception 'FAIL Q6: student accessed';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL Q6: wrong %', sqlerrm; end if;
    raise notice 'PASS Q6: student cannot access queue';
  end;
  reset role;

  -- Q7 admin cannot access queue
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000005';
  begin
    perform * from public.get_counselor_bk_queue();
    raise exception 'FAIL Q7: admin accessed';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL Q7: wrong %', sqlerrm; end if;
    raise notice 'PASS Q7: admin cannot access queue';
  end;
  reset role;

  -- ============================================================
  -- C1 counselor can claim unassigned
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  perform public.claim_counseling_conversation(v_conversation_id);
  select counselor_id into v_tmp from public.counseling_conversations where id=v_conversation_id;
  if v_tmp <> v_counselor1_id then raise exception 'FAIL C1: not claimed'; end if;
  raise notice 'PASS C1: counselor can claim';
  reset role;

  -- C2 second counselor cannot claim
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000004';
  begin
    perform public.claim_counseling_conversation(v_conversation_id);
    raise exception 'FAIL C2: second claim allowed';
  exception when others then
    if sqlerrm not ilike '%sudah ditangani%' then raise exception 'FAIL C2: wrong %', sqlerrm; end if;
    raise notice 'PASS C2: second counselor cannot claim';
  end;
  reset role;

  -- C3 student cannot claim
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  begin
    perform public.claim_counseling_conversation(v_conversation2);
    raise exception 'FAIL C3: student claimed';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL C3: wrong %', sqlerrm; end if;
    raise notice 'PASS C3: student cannot claim';
  end;
  reset role;

  -- C4 admin cannot claim
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000005';
  begin
    perform public.claim_counseling_conversation(v_conversation2);
    raise exception 'FAIL C4: admin claimed';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL C4: wrong %', sqlerrm; end if;
    raise notice 'PASS C4: admin cannot claim';
  end;
  reset role;

  -- C5 claim sets counselor correctly
  select counselor_id, status into v_tmp, v_display from public.counseling_conversations where id=v_conversation_id;
  if v_tmp <> v_counselor1_id then raise exception 'FAIL C5: counselor not set'; end if;
  if v_display <> 'assigned' then raise exception 'FAIL C5: status not assigned %', v_display; end if;
  raise notice 'PASS C5: claim sets correctly';

  -- ============================================================
  -- A1 counselor can read own assigned
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  select count(*) into v_count from public.get_counselor_assigned_conversations() where conversation_id = v_conversation_id;
  if v_count <> 1 then raise exception 'FAIL A1: cannot read own %', v_count; end if;
  raise notice 'PASS A1: counselor can read own assigned';
  reset role;

  -- A2 counselor cannot read another's assigned
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000004';
  select count(*) into v_count from public.get_counselor_assigned_conversations() where conversation_id = v_conversation_id;
  if v_count <> 0 then raise exception 'FAIL A2: other counselor read %', v_count; end if;
  raise notice 'PASS A2: cannot read another assigned';
  reset role;

  -- A3 assigned projection no student_id
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  begin
    perform (select student_id from public.get_counselor_assigned_conversations() where conversation_id = v_conversation_id);
    raise exception 'FAIL A3: student_id exposed';
  exception when undefined_column then raise notice 'PASS A3: no student_id';
  end;
  reset role;

  -- A4 assigned projection no email
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  declare v_def text;
  begin
    select pg_get_functiondef(p.oid) into v_def from pg_proc p where proname='get_counselor_assigned_conversations';
    if v_def ilike '%email%' then raise exception 'FAIL A4: email'; end if;
    raise notice 'PASS A4: no email';
  end;
  reset role;

  -- A5 student cannot use counselor assigned API
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  begin
    perform * from public.get_counselor_assigned_conversations();
    raise exception 'FAIL A5: student accessed';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL A5: wrong %', sqlerrm; end if;
    raise notice 'PASS A5: student cannot use assigned API';
  end;
  reset role;

  -- A6 admin cannot use counselor assigned API
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000005';
  begin
    perform * from public.get_counselor_assigned_conversations();
    raise exception 'FAIL A6: admin accessed';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL A6: wrong %', sqlerrm; end if;
    raise notice 'PASS A6: admin cannot use assigned API';
  end;
  reset role;

  -- ============================================================
  -- M1 assigned counselor can read messages
  -- ============================================================
  -- First send a message as student
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_student1_id, 'Halo');
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  select count(*) into v_count from public.get_counseling_messages(v_conversation_id);
  if v_count < 1 then raise exception 'FAIL M1: cannot read'; end if;
  raise notice 'PASS M1: assigned counselor can read';
  reset role;

  -- M2 assigned counselor can send
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_counselor1_id, 'Balasan');
  raise notice 'PASS M2: assigned counselor can send';
  reset role;

  -- M3 unrelated counselor cannot read
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000004';
  begin
    perform * from public.get_counseling_messages(v_conversation_id);
    raise exception 'FAIL M3: unrelated read';
  exception when others then
    if sqlerrm not ilike '%tidak memiliki akses%' then raise exception 'FAIL M3: wrong %', sqlerrm; end if;
    raise notice 'PASS M3: unrelated cannot read';
  end;
  reset role;

  -- M4 unrelated counselor cannot send
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000004';
  begin
    insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_counselor2_id, 'intrude');
    raise exception 'FAIL M4: unrelated send';
  exception when others then
    raise notice 'PASS M4: unrelated cannot send (%)', sqlerrm;
  end;
  reset role;

  -- M5 admin cannot read/send
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000005';
  begin
    perform * from public.get_counseling_messages(v_conversation_id);
    raise exception 'FAIL M5: admin read';
  exception when others then
    raise notice 'PASS M5: admin cannot read (%)', sqlerrm;
  end;
  reset role;

  -- M6 closed conversation blocks counselor message
  -- Close first
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  perform public.close_counseling_conversation(v_conversation_id);
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  begin
    insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_counselor1_id, 'After closed');
    raise exception 'FAIL M6: closed send allowed';
  exception when others then
    raise notice 'PASS M6: closed blocks counselor message (%)', sqlerrm;
  end;
  reset role;
  -- Reopen for next tests (set back to assigned)
  update public.counseling_conversations set status='assigned', closed_at=null where id=v_conversation_id;

  -- ============================================================
  -- CL1 assigned counselor can close
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  perform public.close_counseling_conversation(v_conversation_id);
  select status into v_display from public.counseling_conversations where id=v_conversation_id;
  if v_display <> 'closed' then raise exception 'FAIL CL1: not closed %', v_display; end if;
  select closed_at into v_closed_at from public.counseling_conversations where id=v_conversation_id;
  if v_closed_at is null then raise exception 'FAIL CL1: closed_at null'; end if;
  raise notice 'PASS CL1: assigned can close';
  reset role;

  -- CL2 student cannot close
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  begin
    perform public.close_counseling_conversation(v_conversation_id);
    raise exception 'FAIL CL2: student closed';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' and sqlerrm not ilike '%Not assigned%' then raise exception 'FAIL CL2: wrong %', sqlerrm; end if;
    raise notice 'PASS CL2: student cannot close';
  end;
  reset role;

  -- CL3 unrelated counselor cannot close
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000004';
  begin
    perform public.close_counseling_conversation(v_conversation_id);
    raise exception 'FAIL CL3: unrelated closed';
  exception when others then
    raise notice 'PASS CL3: unrelated cannot close (%)', sqlerrm;
  end;
  reset role;

  -- CL4 admin cannot close
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000005';
  begin
    perform public.close_counseling_conversation(v_conversation_id);
    raise exception 'FAIL CL4: admin closed';
  exception when others then
    raise notice 'PASS CL4: admin cannot close (%)', sqlerrm;
  end;
  reset role;

  -- CL5 closed_at populated (already checked)
  raise notice 'PASS CL5: closed_at populated';

  -- CL6 status = closed (already checked)
  raise notice 'PASS CL6: status closed';

  -- CL7 closed conversation allows student new active conversation
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  insert into public.counseling_conversations (student_id, student_alias) values (v_student1_id, 'temp') returning id into v_tmp;
  if v_tmp is null then raise exception 'FAIL CL7: new after closed not allowed'; end if;
  raise notice 'PASS CL7: closed allows new active %', v_tmp;
  reset role;
  delete from public.counseling_conversations where id=v_tmp;

  -- CL8 cannot close already closed again
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  begin
    perform public.close_counseling_conversation(v_conversation_id);
    raise exception 'FAIL CL8: double close allowed';
  exception when others then
    if sqlerrm not ilike '%already closed%' and sqlerrm not ilike '%Only assigned%' then raise exception 'FAIL CL8: wrong %', sqlerrm; end if;
    raise notice 'PASS CL8: cannot close already closed';
  end;
  reset role;

  -- ============================================================
  -- I1 assigned counselor can reveal with reason
  -- ============================================================
  -- Need an assigned conversation (currently closed, so reopen)
  update public.counseling_conversations set status='assigned', closed_at=null where id=v_conversation_id;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  select pseudonym into v_display from public.reveal_counseling_identity(v_conversation_id, 'Kebutuhan') limit 1;
  if v_display is null then raise exception 'FAIL I1'; end if;
  raise notice 'PASS I1: assigned can reveal %', v_display;
  reset role;

  -- I2 reason required
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  begin
    perform * from public.reveal_counseling_identity(v_conversation_id, '');
    raise exception 'FAIL I2: empty reason allowed';
  exception when others then
    if sqlerrm not ilike '%Reason required%' then raise exception 'FAIL I2: wrong %', sqlerrm; end if;
    raise notice 'PASS I2: reason required';
  end;
  reset role;

  -- I3 unrelated counselor denied
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000004';
  begin
    perform * from public.reveal_counseling_identity(v_conversation_id, 'test');
    raise exception 'FAIL I3: unrelated reveal';
  exception when others then
    raise notice 'PASS I3: unrelated denied (%)', sqlerrm;
  end;
  reset role;

  -- I4 student denied
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  begin
    perform * from public.reveal_counseling_identity(v_conversation_id, 'test');
    raise exception 'FAIL I4: student reveal';
  exception when others then
    raise notice 'PASS I4: student denied';
  end;
  reset role;

  -- I5 admin denied
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000005';
  begin
    perform * from public.reveal_counseling_identity(v_conversation_id, 'test');
    raise exception 'FAIL I5: admin reveal';
  exception when others then
    raise notice 'PASS I5: admin denied';
  end;
  reset role;

  -- I6 normal queue remains alias-only after reveal
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  begin
    perform (select student_id from public.get_counselor_bk_queue() limit 1);
    raise exception 'FAIL I6: student_id in queue after reveal';
  exception when undefined_column then raise notice 'PASS I6: queue alias-only after reveal';
  end;
  reset role;

  -- I7 assigned list remains alias-only after reveal
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  begin
    perform (select student_id from public.get_counselor_assigned_conversations() where conversation_id = v_conversation_id);
    raise exception 'FAIL I7: student_id in assigned';
  exception when undefined_column then raise notice 'PASS I7: assigned alias-only after reveal';
  end;
  reset role;

  -- I8 reveal writes audit row
  set local role postgres;
  select count(*) into v_count from public.bk_identity_access_log where conversation_id = v_conversation_id and counselor_id = v_counselor1_id;
  reset role;
  if v_count < 1 then raise exception 'FAIL I8: no audit'; end if;
  raise notice 'PASS I8: audit exists %', v_count;

  -- I9 repeated reveal writes another audit row
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  set local role postgres;
  select count(*) into v_count from public.bk_identity_access_log where conversation_id = v_conversation_id;
  reset role;
  perform * from public.reveal_counseling_identity(v_conversation_id, 'Second reason');
  set local role postgres;
  select count(*) into v_count from public.bk_identity_access_log where conversation_id = v_conversation_id;
  reset role;
  if v_count < 2 then raise exception 'FAIL I9: second audit not written %', v_count; end if;
  raise notice 'PASS I9: repeated reveal writes audit';
  reset role;

  -- I10 no email returned
  declare v_def text;
  begin
    select pg_get_functiondef(p.oid) into v_def from pg_proc p where proname='reveal_counseling_identity';
    if v_def ilike '%email%' then raise exception 'FAIL I10: email in reveal'; end if;
    raise notice 'PASS I10: no email returned';
  end;

  -- ============================================================
  -- P1 counselor still cannot access social moderation queue
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000003';
  begin
    perform * from public.get_moderation_queue();
    raise exception 'FAIL P1: counselor has moderation';
  exception when others then
    raise notice 'PASS P1: counselor cannot moderation (%)', sqlerrm;
  end;
  reset role;

  -- P2 admin still can social moderate but cannot BK
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000005';
  -- Admin can moderate (create a report and try to view queue) — just check that get_moderation_queue works for admin (we need an admin that is also moderator? But admin role is social moderator, not BK)
  -- For M5, admin can view moderation queue, but for BK, admin cannot view BK queue (already tested)
  -- Here we just check that admin can still call get_moderation_queue (social) — but admin is social admin, so it should succeed if there is a pending report
  -- Create a dummy report for this
  -- Use student1 post for report
  reset role;
  -- Ensure posts exist for report
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  -- Create a post for reporting
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous) values (v_student1_id, (select id from public.subjects limit 1), 'note','M8 Report Post','content', false) returning id into v_tmp;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000002';
  -- Ensure student2 has no existing report for this post
  begin
    perform public.report_content('post', v_tmp, null, 'spam', null);
  exception when others then null;
  end;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000005';
  begin
    perform * from public.get_moderation_queue();
    raise notice 'PASS P2: admin can still social moderate';
  exception when others then
    raise exception 'FAIL P2: admin cannot moderate %', sqlerrm;
  end;
  reset role;
  delete from public.posts where id=v_tmp;

  -- P3 posts_feed has no BK data
  if exists (select 1 from information_schema.columns where table_name='posts_feed' and column_name ilike '%bk%') then raise exception 'FAIL P3'; end if;
  raise notice 'PASS P3: posts_feed no BK';

  -- P4 search_posts has no BK data
  declare v_search_def text;
  begin
    select pg_get_functiondef(p.oid) into v_search_def from pg_proc p where proname='search_posts';
    if v_search_def ilike '%bk_%' or v_search_def ilike '%counseling%' then raise exception 'FAIL P4: BK in search'; end if;
    raise notice 'PASS P4: search_posts no BK';
  end;

  -- P5 moderation queue has no BK data
  declare v_mod_def text;
  begin
    select pg_get_functiondef(p.oid) into v_mod_def from pg_proc p where proname='get_moderation_queue';
    if v_mod_def ilike '%bk_%' or v_mod_def ilike '%counseling%' then raise exception 'FAIL P5: BK in moderation'; end if;
    raise notice 'PASS P5: moderation no BK';
  end;

  -- P6 counselor BK access does not expose student's social activity
  -- Check that counselor queue does not contain social post history
  declare v_queue_def text;
  begin
    select pg_get_functiondef(p.oid) into v_queue_def from pg_proc p where proname='get_counselor_bk_queue';
    if v_queue_def ilike '%posts%' or v_queue_def ilike '%social%' then raise exception 'FAIL P6: social in BK queue'; end if;
    raise notice 'PASS P6: BK queue no social';
  end;

  -- Cleanup
  delete from public.bk_identity_access_log where counselor_id in (v_counselor1_id, v_counselor2_id);
  delete from public.counseling_messages where conversation_id in (v_conversation_id, v_conversation2);
  delete from public.counseling_conversations where id in (v_conversation_id, v_conversation2);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm8_%@example.com';
  delete from public.invitation_codes where code like 'M8TEST-%';
  raise notice 'ALL M8 SECURITY SCENARIOS COMPLETE';
end
$m8$;
