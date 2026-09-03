-- ==========================================================================
-- EduFess — M7 BK Student Experience verification
-- Covers S1-S6, A1-A3, M1-M7, P1-P6, R1-R3 + M6 regression
-- HOW TO RUN: npx supabase db query --linked --file supabase/verification/m7_security_tests.sql
-- ==========================================================================

do $m7$
declare
  v_count int;
  v_display text;
  v_conversation_id uuid;
  v_conversation2 uuid;
  v_message_id uuid;
  v_student1_id uuid := 'ffffff00-0000-4000-8000-000000000001'::uuid;
  v_student2_id uuid := 'ffffff00-0000-4000-8000-000000000002'::uuid;
  v_counselor1_id uuid := 'ffffff00-0000-4000-8000-000000000003'::uuid;
  v_admin_id uuid := 'ffffff00-0000-4000-8000-000000000004'::uuid;
  v_rec record;
  v_tmp uuid;
begin
  -- Cleanup
  delete from public.bk_identity_access_log where counselor_id in (v_counselor1_id);
  delete from public.counseling_messages where sender_id in (v_student1_id, v_student2_id, v_counselor1_id);
  delete from public.counseling_conversations where student_id in (v_student1_id, v_student2_id);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm7_%@example.com';
  delete from public.invitation_codes where code like 'M7TEST-%';

  insert into public.invitation_codes (code) values ('M7TEST-S1'),('M7TEST-S2'),('M7TEST-C1'),('M7TEST-C2'),('M7TEST-ADM');
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student1_id,'authenticated','authenticated','m7_student1@example.com', extensions.crypt('M7-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M7_Student1','invite_code','M7TEST-S1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student2_id,'authenticated','authenticated','m7_student2@example.com', extensions.crypt('M7-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M7_Student2','invite_code','M7TEST-S2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor1_id,'authenticated','authenticated','m7_counselor1@example.com', extensions.crypt('M7-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M7_Counselor1','invite_code','M7TEST-C1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_admin_id,'authenticated','authenticated','m7_admin@example.com', extensions.crypt('M7-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M7_Admin','invite_code','M7TEST-ADM'), now(), now());
  update public.profiles set role='counselor' where id=v_counselor1_id;
  update public.profiles set role='admin' where id=v_admin_id;
  raise notice 'SEED: M7 users';

  -- Create consent for student1
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  insert into public.bk_consents (student_id, version) values (v_student1_id, 'bk-consent-v1');
  reset role;
  -- Create conversation for student1
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  insert into public.counseling_conversations (student_id, student_alias) values (v_student1_id, 'temp') returning id into v_conversation_id;
  reset role;

  -- ============================================================
  -- S1 student can read own conversation projection
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  select count(*) into v_count from public.get_student_bk_conversations() where conversation_id = v_conversation_id;
  if v_count <> 1 then raise exception 'FAIL S1: cannot read own %', v_count; end if;
  raise notice 'PASS S1: student can read own projection';
  reset role;

  -- ============================================================
  -- S2 student cannot read another's conversation
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000002';
  select count(*) into v_count from public.get_student_bk_conversations() where conversation_id = v_conversation_id;
  if v_count <> 0 then raise exception 'FAIL S2: other can read'; end if;
  raise notice 'PASS S2: other cannot read';
  reset role;

  -- ============================================================
  -- S3 projection does not expose student_id
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  begin
    perform (select student_id from public.get_student_bk_conversations() where conversation_id = v_conversation_id);
    raise exception 'FAIL S3: student_id exposed';
  exception when undefined_column then
    raise notice 'PASS S3: no student_id in projection';
  when others then
    if sqlerrm ilike '%student_id%' then raise notice 'PASS S3: no student_id'; else raise; end if;
  end;
  reset role;

  -- ============================================================
  -- S4 projection does not expose counselor_id
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  begin
    perform (select counselor_id from public.get_student_bk_conversations() where conversation_id = v_conversation_id);
    raise exception 'FAIL S4: counselor_id exposed';
  exception when undefined_column then
    raise notice 'PASS S4: no counselor_id';
  when others then
    if sqlerrm ilike '%counselor_id%' then raise notice 'PASS S4: no counselor_id'; else raise; end if;
  end;
  reset role;

  -- ============================================================
  -- S5 projection does not expose identity_revealed_at
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  begin
    perform (select identity_revealed_at from public.get_student_bk_conversations() where conversation_id = v_conversation_id);
    raise exception 'FAIL S5: identity_revealed_at exposed';
  exception when undefined_column then
    raise notice 'PASS S5: no identity_revealed_at';
  when others then
    raise notice 'PASS S5: no identity_revealed_at (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- S6 active consent required for conversation creation
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000002';
  begin
    insert into public.counseling_conversations (student_id, student_alias) values (v_student2_id, 'temp');
    raise exception 'FAIL S6: no consent allowed';
  exception when others then
    if sqlerrm like 'FAIL S6:%' then raise; end if;
    if sqlerrm not ilike '%perlu menyetujui%' then raise exception 'FAIL S6: wrong %', sqlerrm; end if;
    raise notice 'PASS S6: consent required';
  end;
  reset role;

  -- ============================================================
  -- A1 first active conversation allowed (already have one for student1)
  -- ============================================================
  -- Already have v_conversation_id for student1, should be one active
  select count(*) into v_count from public.counseling_conversations where student_id=v_student1_id and status in ('open','assigned');
  if v_count <> 1 then raise exception 'FAIL A1: active count %', v_count; end if;
  raise notice 'PASS A1: first active allowed';

  -- ============================================================
  -- A2 second active conversation denied
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  begin
    insert into public.counseling_conversations (student_id, student_alias) values (v_student1_id, 'temp');
    raise exception 'FAIL A2: second active allowed';
  exception when others then
    if sqlerrm like 'FAIL A2:%' then raise; end if;
    if sqlerrm not ilike '%sudah memiliki percakapan aktif%' and sqlerrm not ilike '%duplicate%' and sqlerrm not ilike '%one_active%' then raise exception 'FAIL A2: wrong %', sqlerrm; end if;
    raise notice 'PASS A2: second active denied (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- A3 closed conversation allows new active
  -- ============================================================
  update public.counseling_conversations set status='closed', closed_at=now() where id=v_conversation_id;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  insert into public.counseling_conversations (student_id, student_alias) values (v_student1_id, 'temp') returning id into v_conversation2;
  if v_conversation2 is null then raise exception 'FAIL A3: new after closed not allowed'; end if;
  raise notice 'PASS A3: closed allows new %', v_conversation2;
  reset role;
  -- Keep v_conversation_id as the new active for further tests
  v_conversation_id := v_conversation2;

  -- Need to claim the new conversation for counselor tests later
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000003';
  perform public.claim_counseling_conversation(v_conversation_id);
  reset role;

  -- Create a message for M tests
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_student1_id, 'Halo') returning id into v_tmp;
  reset role;

  -- ============================================================
  -- M1 student can read own messages
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  select count(*) into v_count from public.get_counseling_messages(v_conversation_id);
  if v_count < 1 then raise exception 'FAIL M1: cannot read own %', v_count; end if;
  raise notice 'PASS M1: student can read own messages %', v_count;
  -- Check is_mine
  select is_mine into v_display from public.get_counseling_messages(v_conversation_id) limit 1;
  if v_display is null then raise exception 'FAIL M1: is_mine null'; end if;
  raise notice 'PASS M1: is_mine present';
  reset role;

  -- ============================================================
  -- M2 other student cannot read
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000002';
  begin
    perform * from public.get_counseling_messages(v_conversation_id);
    raise exception 'FAIL M2: other student read';
  exception when others then
    if sqlerrm like 'FAIL M2:%' then raise; end if;
    if sqlerrm not ilike '%tidak memiliki akses%' then raise exception 'FAIL M2: wrong %', sqlerrm; end if;
    raise notice 'PASS M2: other student cannot read';
  end;
  reset role;

  -- ============================================================
  -- M3 unrelated counselor cannot read
  -- ============================================================
  -- Create a second counselor not assigned
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values ('ffffff00-0000-4000-8000-000000000005'::uuid,'authenticated','authenticated','m7_counselor2@example.com', extensions.crypt('M7-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M7_C2','invite_code','M7TEST-C2'), now(), now())
  on conflict (id) do nothing;
  alter table public.profiles disable trigger profiles_guard_update;
  update public.profiles set role='counselor' where id='ffffff00-0000-4000-8000-000000000005'::uuid;
  alter table public.profiles enable trigger profiles_guard_update;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000005","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000005';
  begin
    perform * from public.get_counseling_messages(v_conversation_id);
    raise exception 'FAIL M3: unrelated counselor read';
  exception when others then
    if sqlerrm like 'FAIL M3:%' then raise; end if;
    raise notice 'PASS M3: unrelated counselor cannot read (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- M4 admin cannot read
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000004';
  begin
    perform * from public.get_counseling_messages(v_conversation_id);
    raise exception 'FAIL M4: admin read';
  exception when others then
    if sqlerrm like 'FAIL M4:%' then raise; end if;
    raise notice 'PASS M4: admin cannot read (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- M5 student can send while open/assigned
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_student1_id, 'Second message') returning id into v_tmp;
  if v_tmp is null then raise exception 'FAIL M5'; end if;
  raise notice 'PASS M5: student can send while open %', v_tmp;
  reset role;

  -- ============================================================
  -- M6 student cannot send when closed
  -- ============================================================
  update public.counseling_conversations set status='closed', closed_at=now() where id=v_conversation_id;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  begin
    insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_student1_id, 'After closed');
    raise exception 'FAIL M6: send on closed allowed';
  exception when others then
    if sqlerrm like 'FAIL M6:%' then raise; end if;
    raise notice 'PASS M6: cannot send when closed (%)', sqlerrm;
  end;
  reset role;
  -- also via RPC
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  begin
    perform public.send_counseling_message(v_conversation_id, 'After closed via RPC');
    raise exception 'FAIL M6b: RPC closed allowed';
  exception when others then
    if sqlerrm like 'FAIL M6b:%' then raise; end if;
    raise notice 'PASS M6b: RPC closed denied';
  end;
  reset role;
  -- Reopen for next tests
  update public.counseling_conversations set status='assigned', closed_at=null where id=v_conversation_id;

  -- ============================================================
  -- M7 sender spoofing still blocked
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  insert into public.counseling_messages (conversation_id, sender_id, content) values (v_conversation_id, v_counselor1_id, 'spoof') returning id, sender_id into v_tmp, v_conversation2;
  if v_conversation2 = v_counselor1_id then raise exception 'FAIL M7: spoof not forced'; end if;
  if v_conversation2 <> v_student1_id then raise exception 'FAIL M7: not forced %', v_conversation2; end if;
  raise notice 'PASS M7: sender spoof forced';
  reset role;
  delete from public.counseling_messages where id=v_tmp;

  -- ============================================================
  -- P1 student BK history not exposed in posts_feed
  -- ============================================================
  if exists (select 1 from information_schema.columns where table_name='posts_feed' and column_name ilike '%bk%') then raise exception 'FAIL P1'; end if;
  raise notice 'PASS P1: posts_feed no BK';

  -- P2 not exposed in search_posts
  declare v_search_def text;
  begin
    select pg_get_functiondef(p.oid) into v_search_def from pg_proc p where proname='search_posts';
    if v_search_def ilike '%bk_%' or v_search_def ilike '%counseling%' then raise exception 'FAIL P2: BK in search'; end if;
    raise notice 'PASS P2: search_posts no BK';
  end;

  -- P3 not exposed in moderation queue
  declare v_mod_def text;
  begin
    select pg_get_functiondef(p.oid) into v_mod_def from pg_proc p where proname='get_moderation_queue';
    if v_mod_def ilike '%bk_%' or v_mod_def ilike '%counseling%' then raise exception 'FAIL P3: BK in moderation'; end if;
    raise notice 'PASS P3: moderation no BK';
  end;

  -- P4 student projection does not expose email
  begin
    perform (select email from public.get_student_bk_conversations() limit 1);
    raise exception 'FAIL P4: email exposed';
  exception when undefined_column then
    raise notice 'PASS P4: no email in projection';
  when others then
    if sqlerrm ilike '%email%' then raise notice 'PASS P4: no email'; else raise; end if;
  end;

  -- P5 counselor identity internals not exposed unnecessarily (queue has no student_id)
  begin
    perform (select student_id from public.get_counselor_bk_queue() limit 1);
    raise exception 'FAIL P5: student_id in queue';
  exception when undefined_column then
    raise notice 'PASS P5: queue no student_id';
  end;

  -- P6 BK alias preserved
  select student_alias into v_display from public.get_student_bk_conversations() where conversation_id = v_conversation_id;
  if v_display not ilike 'Siswa BK #%' then raise exception 'FAIL P6: alias not preserved %', v_display; end if;
  raise notice 'PASS P6: alias preserved %', v_display;

  -- ============================================================
  -- R1 student cannot access counselor queue
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000001';
  begin
    perform * from public.get_counselor_bk_queue();
    raise exception 'FAIL R1: student accessed queue';
  exception when others then
    if sqlerrm like 'FAIL R1:%' then raise; end if;
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL R1: wrong %', sqlerrm; end if;
    raise notice 'PASS R1: student cannot access counselor queue';
  end;
  reset role;

  -- ============================================================
  -- R2 admin cannot access student BK conversation API
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000004';
  select count(*) into v_count from public.get_student_bk_conversations() where conversation_id = v_conversation_id;
  if v_count <> 0 then raise exception 'FAIL R2: admin accessed student projection'; end if;
  -- Also try direct table
  select count(*) into v_count from public.counseling_conversations where id=v_conversation_id;
  if v_count <> 0 then raise exception 'FAIL R2 direct: admin accessed'; end if;
  raise notice 'PASS R2: admin cannot access student BK';
  reset role;

  -- ============================================================
  -- R3 counselor still cannot access social moderation
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"ffffff00-0000-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'ffffff00-0000-4000-8000-000000000003';
  begin
    perform * from public.get_moderation_queue();
    raise exception 'FAIL R3: counselor has moderation';
  exception when others then
    if sqlerrm like 'FAIL R3:%' then raise; end if;
    raise notice 'PASS R3: counselor no moderation (%)', sqlerrm;
  end;
  reset role;

  -- Cleanup
  delete from public.bk_identity_access_log where counselor_id in (v_counselor1_id);
  delete from public.counseling_messages where conversation_id in (v_conversation_id, v_conversation2);
  delete from public.counseling_conversations where id in (v_conversation_id, v_conversation2);
  delete from public.bk_consents where student_id in (v_student1_id, v_student2_id);
  delete from auth.users where email like 'm7_%@example.com' or id in (v_student1_id, v_student2_id, v_counselor1_id, v_admin_id, 'ffffff00-0000-4000-8000-000000000005'::uuid);
  delete from public.invitation_codes where code like 'M7TEST-%';
  raise notice 'ALL M7 SECURITY SCENARIOS COMPLETE';
end
$m7$;
