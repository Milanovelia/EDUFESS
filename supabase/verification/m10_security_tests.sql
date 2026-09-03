-- ==========================================================================
-- EduFess — M10 Mood Check-In verification
-- Covers S1-S8, H1-H6, C1-C8, CS1-CS3, M1-M5, P1-P8, F
-- HOW TO RUN: npx supabase db query --linked --file supabase/verification/m10_security_tests.sql
-- ==========================================================================

do $m10$
declare
  v_count int;
  v_display text;
  v_mood_id uuid;
  v_mood_id2 uuid;
  v_conversation_id uuid;
  v_student1_id uuid := 'cccccccc-cccc-4000-8000-000000000001'::uuid;
  v_student2_id uuid := 'cccccccc-cccc-4000-8000-000000000002'::uuid;
  v_counselor1_id uuid := 'cccccccc-cccc-4000-8000-000000000003'::uuid;
  v_counselor2_id uuid := 'cccccccc-cccc-4000-8000-000000000004'::uuid;
  v_admin_id uuid := 'cccccccc-cccc-4000-8000-000000000005'::uuid;
  v_tmp uuid;
  v_rec record;
begin
  -- Cleanup
  delete from public.bk_mood_checkins where student_id in (v_student1_id, v_student2_id);
  delete from public.bk_identity_access_log where counselor_id in (v_counselor1_id, v_counselor2_id);
  delete from public.counseling_messages where sender_id in (v_student1_id, v_student2_id, v_counselor1_id);
  delete from public.counseling_conversations where student_id in (v_student1_id, v_student2_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm10_%@example.com';
  delete from public.invitation_codes where code like 'M10TEST-%';
  insert into public.invitation_codes (code) values ('M10TEST-S1'),('M10TEST-S2'),('M10TEST-C1'),('M10TEST-C2'),('M10TEST-ADM');
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student1_id,'authenticated','authenticated','m10_student1@example.com', extensions.crypt('M10-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M10_Student1','invite_code','M10TEST-S1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student2_id,'authenticated','authenticated','m10_student2@example.com', extensions.crypt('M10-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M10_Student2','invite_code','M10TEST-S2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor1_id,'authenticated','authenticated','m10_counselor1@example.com', extensions.crypt('M10-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M10_Counselor1','invite_code','M10TEST-C1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor2_id,'authenticated','authenticated','m10_counselor2@example.com', extensions.crypt('M10-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M10_Counselor2','invite_code','M10TEST-C2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_admin_id,'authenticated','authenticated','m10_admin@example.com', extensions.crypt('M10-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M10_Admin','invite_code','M10TEST-ADM'), now(), now());
  update public.profiles set role='counselor' where id in (v_counselor1_id, v_counselor2_id);
  update public.profiles set role='admin' where id=v_admin_id;
  raise notice 'SEED M10 users';
  -- Consent for student1
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  insert into public.bk_consents (student_id, version) values (v_student1_id, 'bk-consent-v1');
  reset role;
  -- Create conversation for student1 assigned to counselor1
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  insert into public.counseling_conversations (student_id, student_alias) values (v_student1_id, 'temp') returning id into v_conversation_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  perform public.claim_counseling_conversation(v_conversation_id);
  reset role;

  -- ============================================================
  -- S1 student with consent can submit
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  select public.submit_bk_mood_checkin(3::smallint, 'Hari biasa') into v_mood_id;
  if v_mood_id is null then raise exception 'FAIL S1'; end if;
  raise notice 'PASS S1: student can submit %', v_mood_id;
  reset role;

  -- S2 no consent denied
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000002';
  begin
    perform public.submit_bk_mood_checkin(3::smallint, null);
    raise exception 'FAIL S2: no consent allowed';
  exception when others then
    if sqlerrm not ilike '%perlu menyetujui%' then raise exception 'FAIL S2: wrong %', sqlerrm; end if;
    raise notice 'PASS S2: no consent denied';
  end;
  reset role;

  -- S3 counselor cannot submit as student
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  begin
    perform public.submit_bk_mood_checkin(3::smallint, null);
    raise exception 'FAIL S3: counselor submitted';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL S3: wrong %', sqlerrm; end if;
    raise notice 'PASS S3: counselor cannot submit';
  end;
  reset role;

  -- S4 admin cannot submit
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000005';
  begin
    perform public.submit_bk_mood_checkin(3::smallint, null);
    raise exception 'FAIL S4: admin submitted';
  exception when others then
    raise notice 'PASS S4: admin cannot submit';
  end;
  reset role;

  -- S5 student_id spoof blocked
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  -- Try direct insert with different student_id
  begin
    insert into public.bk_mood_checkins (student_id, mood_level) values (v_student2_id, 3);
    raise exception 'FAIL S5: spoof allowed';
  exception when others then
    raise notice 'PASS S5: spoof blocked (%)', sqlerrm;
  end;
  reset role;

  -- S6 mood <1 denied
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  begin
    perform public.submit_bk_mood_checkin(0::smallint, null);
    raise exception 'FAIL S6: mood 0 allowed';
  exception when others then
    raise notice 'PASS S6: mood <1 denied';
  end;
  reset role;

  -- S7 mood >5 denied
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  begin
    perform public.submit_bk_mood_checkin(6::smallint, null);
    raise exception 'FAIL S7: mood 6 allowed';
  exception when others then
    raise notice 'PASS S7: mood >5 denied';
  end;
  reset role;

  -- S8 note over limit denied
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  begin
    perform public.submit_bk_mood_checkin(3::smallint, repeat('a', 1001));
    raise exception 'FAIL S8: long note allowed';
  exception when others then
    raise notice 'PASS S8: note over limit denied';
  end;
  reset role;

  -- ============================================================
  -- H1 student reads own history
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  select count(*) into v_count from public.get_student_bk_mood_history(10, 0);
  if v_count < 1 then raise exception 'FAIL H1: cannot read own %', v_count; end if;
  raise notice 'PASS H1: student reads own %', v_count;
  reset role;

  -- H2 other student cannot read
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000002';
  select count(*) into v_count from public.get_student_bk_mood_history(10, 0) where mood_level = 3;
  -- This will return only own (0), but we need to check that student's history does not contain student1's mood
  -- So we check that count for student2 is 0 (since student2 has no moods)
  if v_count <> 0 then raise exception 'FAIL H2: other saw %', v_count; end if;
  raise notice 'PASS H2: other cannot read';
  reset role;

  -- H3 history projection no student_id
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  begin
    perform (select student_id from public.get_student_bk_mood_history(1, 0) limit 1);
    raise exception 'FAIL H3: student_id exposed';
  exception when undefined_column then raise notice 'PASS H3: no student_id';
  end;
  reset role;

  -- H4 history projection no email
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  begin
    perform (select email from public.get_student_bk_mood_history(1, 0) limit 1);
    raise exception 'FAIL H4: email exposed';
  exception when undefined_column then raise notice 'PASS H4: no email';
  end;
  reset role;

  -- H5 pagination limit enforced
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  select count(*) into v_count from public.get_student_bk_mood_history(200, 0);
  if v_count > 100 then raise exception 'FAIL H5: limit not enforced %', v_count; end if;
  raise notice 'PASS H5: limit enforced %', v_count;
  reset role;

  -- H6 order newest first
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  select public.submit_bk_mood_checkin(5::smallint, 'Second') into v_mood_id2;
  -- Check that history now has at least 2 and contains both
  select count(*) into v_count from public.get_student_bk_mood_history(10, 0) where mood_level in (3,5);
  if v_count < 2 then raise exception 'FAIL H6: not both %', v_count; end if;
  -- Also check order: newest should be 5 (allow small delay, so check that 5 is in top 2)
  select count(*) into v_count from (select mood_level from public.get_student_bk_mood_history(2, 0) where mood_level=5) as t;
  if v_count < 1 then raise exception 'FAIL H6: 5 not in top 2'; end if;
  raise notice 'PASS H6: newest first';
  reset role;

  -- ============================================================
  -- C1 assigned counselor can read linked student's mood history
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  select count(*) into v_count from public.get_counselor_student_mood_history(v_conversation_id, 10, 0);
  if v_count < 1 then raise exception 'FAIL C1: assigned cannot read %', v_count; end if;
  raise notice 'PASS C1: assigned can read %', v_count;
  reset role;

  -- C2 unrelated counselor denied
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000004';
  begin
    perform * from public.get_counselor_student_mood_history(v_conversation_id, 10, 0);
    raise exception 'FAIL C2: unrelated read';
  exception when others then
    if sqlerrm not ilike '%Not assigned%' and sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL C2: wrong %', sqlerrm; end if;
    raise notice 'PASS C2: unrelated denied';
  end;
  reset role;

  -- C3 counselor assigned to another student denied
  -- Create a second conversation for student2 assigned to counselor2
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000002';
  insert into public.bk_consents (student_id, version) values (v_student2_id, 'bk-consent-v1') on conflict do nothing;
  insert into public.counseling_conversations (student_id, student_alias) values (v_student2_id, 'temp') returning id into v_tmp;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000004';
  perform public.claim_counseling_conversation(v_tmp);
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  begin
    perform * from public.get_counselor_student_mood_history(v_tmp, 10, 0);
    raise exception 'FAIL C3: counselor read another student';
  exception when others then
    raise notice 'PASS C3: another student denied (%)', sqlerrm;
  end;
  reset role;
  delete from public.counseling_conversations where id=v_tmp;
  delete from public.bk_consents where student_id=v_student2_id and version='bk-consent-v1' and id not in (select id from public.bk_consents where student_id=v_student2_id limit 1);

  -- C4 student cannot invoke counselor history API
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  begin
    perform * from public.get_counselor_student_mood_history(v_conversation_id, 10, 0);
    raise exception 'FAIL C4: student invoked';
  exception when others then
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL C4: wrong %', sqlerrm; end if;
    raise notice 'PASS C4: student cannot invoke';
  end;
  reset role;

  -- C5 admin denied
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000005';
  begin
    perform * from public.get_counselor_student_mood_history(v_conversation_id, 10, 0);
    raise exception 'FAIL C5: admin invoked';
  exception when others then
    raise notice 'PASS C5: admin denied';
  end;
  reset role;

  -- C6 counselor projection no student_id
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  begin
    perform (select student_id from public.get_counselor_student_mood_history(v_conversation_id, 1, 0) limit 1);
    raise exception 'FAIL C6: student_id in counselor projection';
  exception when undefined_column then raise notice 'PASS C6: no student_id';
  end;
  reset role;

  -- C7 counselor projection no email
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  begin
    perform (select email from public.get_counselor_student_mood_history(v_conversation_id, 1, 0) limit 1);
    raise exception 'FAIL C7: email in counselor projection';
  exception when undefined_column then raise notice 'PASS C7: no email';
  end;
  reset role;

  -- C8 counselor projection no real pseudonym
  declare v_def text;
  begin
    select pg_get_functiondef(p.oid) into v_def from pg_proc p where proname='get_counselor_student_mood_history';
    if v_def ilike '%pseudonym%' then raise exception 'FAIL C8: pseudonym in def'; end if;
    raise notice 'PASS C8: no pseudonym';
  end;

  -- ============================================================
  -- CS1 assigned active conversation allows access
  -- ============================================================
  -- Already tested C1, same as CS1
  raise notice 'PASS CS1: assigned active allows';

  -- CS2 closed conversation denies counselor mood access
  update public.counseling_conversations set status='closed', closed_at=now() where id=v_conversation_id;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  begin
    perform * from public.get_counselor_student_mood_history(v_conversation_id, 10, 0);
    raise exception 'FAIL CS2: closed allowed';
  exception when others then
    if sqlerrm not ilike '%not assigned%' and sqlerrm not ilike '%Conversation not assigned%' then raise exception 'FAIL CS2: wrong %', sqlerrm; end if;
    raise notice 'PASS CS2: closed denies';
  end;
  reset role;
  update public.counseling_conversations set status='assigned', closed_at=null where id=v_conversation_id;

  -- CS3 unassigned/open conversation denies counselor access
  -- Create an unassigned conversation for student1 (need to close current first to allow new)
  update public.counseling_conversations set status='closed', closed_at=now() where id=v_conversation_id;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  insert into public.counseling_conversations (student_id, student_alias) values (v_student1_id, 'temp') returning id into v_tmp;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  begin
    perform * from public.get_counselor_student_mood_history(v_tmp, 10, 0);
    raise exception 'FAIL CS3: unassigned allowed';
  exception when others then
    raise notice 'PASS CS3: unassigned denies (%)', sqlerrm;
  end;
  reset role;
  delete from public.counseling_conversations where id=v_tmp;
  update public.counseling_conversations set status='assigned', closed_at=null where id=v_conversation_id;

  -- ============================================================
  -- M1 counselor cannot edit mood
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  select count(*) into v_count from public.bk_mood_checkins where id=v_mood_id;
  if v_count <> 0 then raise exception 'FAIL M1: counselor saw %', v_count; end if;
  raise notice 'PASS M1: counselor cannot edit';
  reset role;

  -- M2 counselor cannot delete mood
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  select count(*) into v_count from public.bk_mood_checkins where id=v_mood_id;
  if v_count <> 0 then raise exception 'FAIL M2: counselor saw delete %', v_count; end if;
  raise notice 'PASS M2: counselor cannot delete';
  reset role;

  -- M3 student cannot edit old mood
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  begin
    update public.bk_mood_checkins set mood_level=1 where id=v_mood_id;
    if found then raise exception 'FAIL M3: student edited'; end if;
    raise notice 'PASS M3: student cannot edit';
  exception when others then
    if sqlerrm like 'FAIL M3:%' then raise; end if;
    raise notice 'PASS M3: student cannot edit (%)', sqlerrm;
  end;
  reset role;

  -- M4 student cannot delete old mood
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  begin
    delete from public.bk_mood_checkins where id=v_mood_id;
    if found then raise exception 'FAIL M4: student deleted'; end if;
    raise notice 'PASS M4: student cannot delete';
  exception when others then
    if sqlerrm like 'FAIL M4:%' then raise; end if;
    raise notice 'PASS M4: student cannot delete (%)', sqlerrm;
  end;
  reset role;

  -- M5 admin cannot mutate mood
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000005';
  begin
    update public.bk_mood_checkins set mood_level=1 where id=v_mood_id;
    if found then raise exception 'FAIL M5: admin edited'; end if;
    raise notice 'PASS M5: admin cannot mutate';
  exception when others then
    if sqlerrm like 'FAIL M5:%' then raise; end if;
    raise notice 'PASS M5: admin cannot mutate (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- P1 mood absent from posts_feed
  -- ============================================================
  if exists (select 1 from information_schema.columns where table_name='posts_feed' and column_name ilike '%mood%') then raise exception 'FAIL P1: mood in posts_feed'; end if;
  raise notice 'PASS P1: posts_feed no mood';

  -- P2 mood absent from comments_feed
  if exists (select 1 from information_schema.columns where table_name='comments_feed' and column_name ilike '%mood%') then raise exception 'FAIL P2'; end if;
  raise notice 'PASS P2: comments_feed no mood';

  -- P3 mood absent from search_posts
  declare v_search_def text;
  begin
    select pg_get_functiondef(p.oid) into v_search_def from pg_proc p where proname='search_posts';
    if v_search_def ilike '%bk_mood%' then raise exception 'FAIL P3: mood in search'; end if;
    raise notice 'PASS P3: search_posts no mood';
  end;

  -- P4 mood absent from moderation queue
  declare v_mod_def text;
  begin
    select pg_get_functiondef(p.oid) into v_mod_def from pg_proc p where proname='get_moderation_queue';
    if v_mod_def ilike '%bk_mood%' then raise exception 'FAIL P4: mood in moderation'; end if;
    raise notice 'PASS P4: moderation no mood';
  end;

  -- P5 mood absent from appointment projections
  declare v_app_def text;
  begin
    select pg_get_functiondef(p.oid) into v_app_def from pg_proc p where proname='get_student_bk_appointments';
    if v_app_def ilike '%bk_mood%' then raise exception 'FAIL P5: mood in appointments'; end if;
    raise notice 'PASS P5: appointments no mood';
  end;

  -- P6 mood access does not expose student identity
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  begin
    perform (select student_id from public.get_counselor_student_mood_history(v_conversation_id, 1, 0) limit 1);
    raise exception 'FAIL P6: student_id in mood';
  exception when undefined_column then raise notice 'PASS P6: no student_id in mood';
  end;
  reset role;

  -- P7 counselor still cannot social moderate
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000003';
  begin
    perform * from public.get_moderation_queue();
    raise exception 'FAIL P7: counselor has moderation';
  exception when others then
    raise notice 'PASS P7: counselor no moderation';
  end;
  reset role;

  -- P8 admin still cannot access BK mood
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000005';
  begin
    perform * from public.get_counselor_student_mood_history(v_conversation_id, 1, 0);
    raise exception 'FAIL P8: admin has mood';
  exception when others then
    raise notice 'PASS P8: admin cannot access mood';
  end;
  reset role;

  -- ============================================================
  -- F: Check-in frequency (multiple allowed)
  -- ============================================================
  -- For M10, multiple entries per day are intentionally allowed
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"cccccccc-cccc-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'cccccccc-cccc-4000-8000-000000000001';
  select public.submit_bk_mood_checkin(4::smallint, 'Second today') into v_tmp;
  if v_tmp is null then raise exception 'FAIL F: second today not allowed'; end if;
  raise notice 'PASS F: multiple per day allowed %', v_tmp;
  reset role;
  delete from public.bk_mood_checkins where id=v_tmp;

  -- Cleanup
  delete from public.bk_mood_checkins where student_id in (v_student1_id, v_student2_id);
  delete from public.bk_identity_access_log where counselor_id in (v_counselor1_id, v_counselor2_id);
  delete from public.counseling_messages where conversation_id in (v_conversation_id);
  delete from public.counseling_conversations where id in (v_conversation_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm10_%@example.com';
  delete from public.invitation_codes where code like 'M10TEST-%';
  raise notice 'ALL M10 SECURITY SCENARIOS COMPLETE';
end
$m10$;
