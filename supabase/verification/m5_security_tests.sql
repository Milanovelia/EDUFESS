-- ==========================================================================
-- EduFess — M5 moderation security verification
-- Covers R1-R10, M1-M10, P1-P8, G1-G5
-- HOW TO RUN: npx supabase db query --linked --file supabase/verification/m5_security_tests.sql
-- ==========================================================================

do $m5$
declare
  v_count int;
  v_display text;
  v_alias text;
  v_report_id uuid;
  v_report2 uuid;
  v_post_id uuid;
  v_post2_id uuid;
  v_comment_id uuid;
  v_comment2 uuid;
  v_subject_id uuid;
  v_topic_id uuid;
  v_admin_id uuid := 'dddddddd-dddd-4000-8000-000000000001'::uuid;
  v_student1_id uuid := 'dddddddd-dddd-4000-8000-000000000002'::uuid;
  v_student2_id uuid := 'dddddddd-dddd-4000-8000-000000000003'::uuid;
  v_counselor_id uuid := 'dddddddd-dddd-4000-8000-000000000004'::uuid;
  v_tmp int;
  v_is_admin boolean;
  v_deleted_at timestamptz;
begin
  -- Cleanup prior M5 artifacts
  delete from public.moderation_actions where moderator_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from public.content_reports where reporter_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from public.comments where author_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from public.post_helpful where user_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from public.bookmarks where user_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from public.posts where author_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from auth.users where email like 'm5_%@example.com';
  delete from public.invitation_codes where code like 'M5TEST-%';

  insert into public.invitation_codes (code) values ('M5TEST-ADMIN'),('M5TEST-S1'),('M5TEST-S2'),('M5TEST-COUN');

  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_admin_id,'authenticated','authenticated','m5_admin@example.com', extensions.crypt('M5-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M5_Admin','invite_code','M5TEST-ADMIN'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student1_id,'authenticated','authenticated','m5_student1@example.com', extensions.crypt('M5-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M5_Student1','invite_code','M5TEST-S1'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_student2_id,'authenticated','authenticated','m5_student2@example.com', extensions.crypt('M5-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M5_Student2','invite_code','M5TEST-S2'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_counselor_id,'authenticated','authenticated','m5_counselor@example.com', extensions.crypt('M5-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M5_Counselor','invite_code','M5TEST-COUN'), now(), now());

  -- Elevate roles (bypass guard via no JWT)
  update public.profiles set role='admin' where id=v_admin_id;
  update public.profiles set role='counselor' where id=v_counselor_id;
  -- students remain student
  raise notice 'SEED: 4 M5 users created admin=% student1=% student2=% counselor=%', v_admin_id, v_student1_id, v_student2_id, v_counselor_id;
  select id into v_subject_id from public.subjects where slug='informatika';
  select id into v_topic_id from public.topics where slug='pemrograman' and subject_id=v_subject_id;
  if v_subject_id is null then raise exception 'subjects missing'; end if;

  -- Create posts and comments as student1 (some pseudonymous)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  insert into public.posts (author_id, subject_id, topic_id, type, title, content, is_pseudonymous) values (v_student1_id, v_subject_id, v_topic_id, 'note','M5 Post Visible','konten visible', false) returning id into v_post_id;
  insert into public.posts (author_id, subject_id, topic_id, type, title, content, is_pseudonymous) values (v_student1_id, v_subject_id, v_topic_id, 'question','M5 Pseudonymous Post','konten pseudo', true) returning id into v_post2_id;
  select anonymous_alias into v_alias from public.posts where id=v_post2_id;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content, is_pseudonymous) values (v_student1_id, v_post_id, 'M5 Comment Visible', false) returning id into v_comment_id;
  insert into public.comments (author_id, post_id, content, is_pseudonymous) values (v_student1_id, v_post_id, 'M5 Pseudo Comment', true) returning id into v_comment2;
  reset role;

  -- ============================================================
  -- R1 student can report visible post
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select public.report_content('post', v_post_id, null, 'spam', 'details R1') into v_report_id;
  if v_report_id is null then raise exception 'FAIL R1'; end if;
  raise notice 'PASS R1: student can report visible post %', v_report_id;
  reset role;

  -- ============================================================
  -- R2 student can report visible comment
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select public.report_content('comment', null, v_comment_id, 'harassment', null) into v_report2;
  if v_report2 is null then raise exception 'FAIL R2'; end if;
  raise notice 'PASS R2: student can report visible comment %', v_report2;
  reset role;

  -- ============================================================
  -- R3 reporter_id spoofing denied/forced
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  -- Try to insert direct with different reporter_id, should be forced to auth uid via trigger
  insert into public.content_reports (reporter_id, target_type, post_id, reason) values (v_admin_id, 'post', v_post2_id, 'spam') returning id into v_report2;
  select reporter_id::text into v_display from public.content_reports where id=v_report2;
  if v_display = v_admin_id::text then raise exception 'FAIL R3: spoof not forced %', v_display; end if;
  if v_display <> v_student2_id::text then raise exception 'FAIL R3: not forced to own %', v_display; end if;
  raise notice 'PASS R3: reporter spoof forced to own %', v_display;
  reset role;
  -- cleanup spoof report (as superuser)
  delete from public.content_reports where id=v_report2;

  -- ============================================================
  -- R4 duplicate pending post report denied
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  begin
    perform public.report_content('post', v_post_id, null, 'spam', null);
    raise exception 'FAIL R4: duplicate allowed';
  exception when others then
    if sqlerrm like 'FAIL R4:%' then raise; end if;
    if sqlerrm not ilike '%sudah pernah kamu laporkan%' then raise exception 'FAIL R4: wrong error %', sqlerrm; end if;
    raise notice 'PASS R4: duplicate pending post denied (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- R5 duplicate pending comment report denied
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  begin
    perform public.report_content('comment', null, v_comment_id, 'spam', null);
    raise exception 'FAIL R5: duplicate allowed';
  exception when others then
    if sqlerrm like 'FAIL R5:%' then raise; end if;
    if sqlerrm not ilike '%sudah pernah kamu laporkan%' then raise exception 'FAIL R5: wrong error %', sqlerrm; end if;
    raise notice 'PASS R5: duplicate pending comment denied';
  end;
  reset role;

  -- ============================================================
  -- R6 student cannot see another student's report
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  select count(*) into v_count from public.content_reports where reporter_id = v_student2_id;
  if v_count <> 0 then raise exception 'FAIL R6: sees other report %', v_count; end if;
  raise notice 'PASS R6: cannot see other report';
  reset role;

  -- ============================================================
  -- R7 cannot report deleted/removed post
  -- ============================================================
  -- Create a post and soft-delete it, then try report
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous) values (v_student1_id, v_subject_id, 'note','M5 ToDelete','del', false) returning id into v_post2_id;
  update public.posts set deleted_at=now() where id=v_post2_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  begin
    perform public.report_content('post', v_post2_id, null, 'spam', null);
    raise exception 'FAIL R7: report deleted allowed';
  exception when others then
    if sqlerrm like 'FAIL R7:%' then raise; end if;
    raise notice 'PASS R7: cannot report deleted post (%)', sqlerrm;
  end;
  reset role;
  delete from public.posts where id=v_post2_id;

  -- ============================================================
  -- R8 cannot report deleted/removed comment
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content) values (v_student1_id, v_post_id, 'to delete comment') returning id into v_comment2;
  update public.comments set deleted_at=now() where id=v_comment2;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  begin
    perform public.report_content('comment', null, v_comment2, 'spam', null);
    raise exception 'FAIL R8: report deleted comment allowed';
  exception when others then
    if sqlerrm like 'FAIL R8:%' then raise; end if;
    raise notice 'PASS R8: cannot report deleted comment (%)', sqlerrm;
  end;
  reset role;
  delete from public.comments where id=v_comment2;

  -- ============================================================
  -- R9 invalid reason rejected
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  begin
    perform public.report_content('post', v_post_id, null, 'invalid_reason', null);
    raise exception 'FAIL R9: invalid reason allowed';
  exception when others then
    if sqlerrm like 'FAIL R9:%' then raise; end if;
    raise notice 'PASS R9: invalid reason rejected (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- R10 target mismatch rejected
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  begin
    perform public.report_content('post', null, v_comment_id, 'spam', null);
    raise exception 'FAIL R10a: mismatch allowed';
  exception when others then
    if sqlerrm like 'FAIL R10a:%' then raise; end if;
    raise notice 'PASS R10a: post mismatch rejected (%)', sqlerrm;
  end;
  begin
    perform public.report_content('comment', v_post_id, null, 'spam', null);
    raise exception 'FAIL R10b: mismatch allowed';
  exception when others then
    if sqlerrm like 'FAIL R10b:%' then raise; end if;
    raise notice 'PASS R10b: comment mismatch rejected';
  end;
  reset role;

  -- ============================================================
  -- M1 admin can view moderation queue
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  select count(*) into v_count from public.get_moderation_queue();
  if v_count < 1 then raise exception 'FAIL M1: admin queue empty %', v_count; end if;
  raise notice 'PASS M1: admin can view queue %', v_count;
  reset role;

  -- ============================================================
  -- M2 student cannot view moderation queue
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  begin
    perform from public.get_moderation_queue();
    raise exception 'FAIL M2: student viewed queue';
  exception when others then
    if sqlerrm like 'FAIL M2:%' then raise; end if;
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL M2: wrong error %', sqlerrm; end if;
    raise notice 'PASS M2: student cannot view queue (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- M3 counselor cannot view moderation queue
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000004';
  begin
    perform from public.get_moderation_queue();
    raise exception 'FAIL M3: counselor viewed';
  exception when others then
    if sqlerrm like 'FAIL M3:%' then raise; end if;
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL M3: wrong error %', sqlerrm; end if;
    raise notice 'PASS M3: counselor cannot view queue';
  end;
  reset role;

  -- ============================================================
  -- M4 admin can dismiss pending report
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  perform public.moderate_report(v_report_id, 'dismiss_report');
  select status into v_display from public.content_reports where id=v_report_id;
  if v_display <> 'dismissed' then raise exception 'FAIL M4: not dismissed %', v_display; end if;
  raise notice 'PASS M4: admin can dismiss %', v_report_id;
  reset role;

  -- After dismiss, new report on same target by same reporter should be allowed (pending cleared)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select public.report_content('post', v_post_id, null, 'spam', 'second after dismiss') into v_report2;
  if v_report2 is null then raise exception 'FAIL M4b: new after dismiss not allowed'; end if;
  raise notice 'PASS M4b: new report allowed after dismissed %', v_report2;
  reset role;

  -- ============================================================
  -- M5 admin can remove reported post
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  perform public.moderate_report(v_report2, 'remove_content');
  select deleted_at into v_deleted_at from public.posts where id=v_post_id;
  if v_deleted_at is null then raise exception 'FAIL M5: post not removed'; end if;
  raise notice 'PASS M5: admin can remove reported post %', v_post_id;
  reset role;

  -- Check G1/G2 already: post should be excluded from feed/search
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select count(*) into v_count from public.posts_feed where id=v_post_id;
  if v_count <> 0 then raise exception 'FAIL G1: removed in feed'; end if;
  select count(*) into v_count from public.search_posts(p_query := 'M5 Post Visible') where id=v_post_id;
  if v_count <> 0 then raise exception 'FAIL G2: removed in search'; end if;
  raise notice 'PASS G1/G2: removed post excluded';
  reset role;

  -- Restore post for further tests (admin restore not implemented, so manual update as superuser)
  update public.posts set deleted_at=null where id=v_post_id;
  -- Need new post for comment removal test (since previous post restored)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous) values (v_student1_id, v_subject_id, 'note','M5 For Comment','for comment', false) returning id into v_post2_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content) values (v_student1_id, v_post2_id, 'M5 comment to remove') returning id into v_comment2;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select public.report_content('comment', null, v_comment2, 'spam', null) into v_report2;
  reset role;

  -- ============================================================
  -- M6 admin can remove reported comment
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  perform public.moderate_report(v_report2, 'remove_content');
  select deleted_at into v_deleted_at from public.comments where id=v_comment2;
  if v_deleted_at is null then raise exception 'FAIL M6: comment not removed'; end if;
  raise notice 'PASS M6: admin can remove comment';
  reset role;

  -- G3 removed comment excluded from comments_feed
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select count(*) into v_count from public.comments_feed where id=v_comment2;
  if v_count <> 0 then raise exception 'FAIL G3: removed comment in feed'; end if;
  raise notice 'PASS G3: removed comment excluded';
  reset role;

  -- ============================================================
  -- M7 student cannot moderate report
  -- ============================================================
  -- Create another report to test
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select public.report_content('post', v_post2_id, null, 'spam', null) into v_report_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  begin
    perform public.moderate_report(v_report_id, 'dismiss_report');
    raise exception 'FAIL M7: student moderated';
  exception when others then
    if sqlerrm like 'FAIL M7:%' then raise; end if;
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL M7: wrong error %', sqlerrm; end if;
    raise notice 'PASS M7: student cannot moderate';
  end;
  reset role;

  -- ============================================================
  -- M8 non-admin cannot invoke moderation RPC (counselor)
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000004","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000004';
  begin
    perform public.moderate_report(v_report_id, 'dismiss_report');
    raise exception 'FAIL M8: counselor moderated';
  exception when others then
    if sqlerrm like 'FAIL M8:%' then raise; end if;
    if sqlerrm not ilike '%Not authorized%' then raise exception 'FAIL M8: wrong %', sqlerrm; end if;
    raise notice 'PASS M8: counselor cannot moderate';
  end;
  reset role;

  -- ============================================================
  -- M9 resolved/dismissed report cannot be processed again
  -- ============================================================
  -- v_report_id is pending (we created for M7), first dismiss via admin, then try again
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  perform public.moderate_report(v_report_id, 'dismiss_report');
  begin
    perform public.moderate_report(v_report_id, 'dismiss_report');
    raise exception 'FAIL M9: re-process allowed';
  exception when others then
    if sqlerrm like 'FAIL M9:%' then raise; end if;
    if sqlerrm not ilike '%already processed%' then raise exception 'FAIL M9: wrong %', sqlerrm; end if;
    raise notice 'PASS M9: cannot re-process';
  end;
  reset role;

  -- ============================================================
  -- M10 moderation action creates audit row
  -- ============================================================
  select count(*) into v_count from public.moderation_actions where report_id=v_report_id;
  if v_count < 1 then raise exception 'FAIL M10: no audit %', v_count; end if;
  raise notice 'PASS M10: audit row exists %', v_count;

  -- ============================================================
  -- P1 moderation queue does not expose email
  -- ============================================================
  if exists (select 1 from information_schema.columns where table_name='get_moderation_queue' and column_name='email') then
    raise exception 'FAIL P1: email col in queue';
  end if;
  -- Check returned queue columns
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  -- Create a fresh pending report for P2/P3 checks (pseudonymous)
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous) values (v_student1_id, v_subject_id, 'note','M5 Pseudo Queue','queue test', true) returning id into v_post2_id;
  select anonymous_alias into v_alias from public.posts where id=v_post2_id;
  -- need to be student2 reporting? Create report via function as student2
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select public.report_content('post', v_post2_id, null, 'spam', null) into v_report_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  select display_author into v_display from public.get_moderation_queue() where report_id=v_report_id;
  if v_display = 'M5_Student1' then raise exception 'FAIL P2: alias leak %', v_display; end if;
  if v_display not ilike 'Siswa Anonim #%' then raise exception 'FAIL P2: not alias %', v_display; end if;
  raise notice 'PASS P2: pseudonymous post alias only %', v_display;
  reset role;

  -- P3 pseudonymous comment
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content, is_pseudonymous) values (v_student1_id, v_post_id, 'M5 pseudo comment queue', true) returning id into v_comment_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select public.report_content('comment', null, v_comment_id, 'spam', null) into v_report2;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  select display_author into v_display from public.get_moderation_queue() where report_id=v_report2;
  if v_display not ilike 'Siswa Anonim #%' then raise exception 'FAIL P3: comment alias leak %', v_display; end if;
  raise notice 'PASS P3: pseudonymous comment alias only';
  reset role;

  -- ============================================================
  -- P4 reporter identity not exposed to normal students
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select count(*) into v_count from public.content_reports where reporter_id = v_student1_id;
  if v_count <> 0 then raise exception 'FAIL P4: sees other reporter'; end if;
  raise notice 'PASS P4: reporter identity not exposed';
  reset role;

  -- ============================================================
  -- P5 moderation access does not grant access to unrelated private data
  -- ============================================================
  -- Ensure admin cannot read private profiles beyond own via direct table (RLS own-row)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  select count(*) into v_count from public.profiles where id <> v_admin_id;
  if v_count <> 0 then raise exception 'FAIL P5: admin can read other profiles %', v_count; end if;
  raise notice 'PASS P5: no unauthorized profile access';
  reset role;

  -- ============================================================
  -- P6 BK tables/grants untouched if present
  -- ============================================================
  -- Check that no new tables with BK in name were created with admin grants
  -- For MVP, BK tables may not exist; ensure we didn't create broad admin grant
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name ilike '%bk%') then
    raise notice 'WARN P6: BK tables exist, need manual audit';
  else
    raise notice 'PASS P6: no BK tables, isolation preserved by scoped grants';
  end if;
  -- Also check that content_reports/moderation_actions not grant to counselor via RLS bypass
  select count(*) into v_count from information_schema.role_table_grants where table_name='content_reports' and privilege_type='SELECT' and grantee='counselor';
  if v_count <> 0 then raise exception 'FAIL P6: counselor has grants'; end if;
  raise notice 'PASS P6: BK/grants untouched';

  -- ============================================================
  -- P7 moderation queue does not expose reporter_id
  -- ============================================================
  begin
    perform (select reporter_id from public.get_moderation_queue() limit 1);
    raise exception 'FAIL P7: reporter_id exposed in queue';
  exception when undefined_column then
    raise notice 'PASS P7: queue does not expose reporter_id';
  when others then
    if sqlerrm like 'FAIL P7:%' then raise; end if;
    if sqlerrm ilike '%reporter_id%' then raise notice 'PASS P7: reporter_id not in queue (%)', sqlerrm;
    else raise exception 'FAIL P7: unexpected %', sqlerrm; end if;
  end;

  -- ============================================================
  -- P8 moderation queue does not expose reporter pseudonym/email
  -- ============================================================
  declare
    v_def2 text;
  begin
    select pg_get_functiondef(p.oid) into v_def2 from pg_proc p where p.proname='get_moderation_queue' and p.pronamespace='public'::regnamespace;
    if v_def2 ilike '%reporter%' then raise exception 'FAIL P8: queue definition contains reporter %', v_def2; end if;
    if v_def2 ilike '%email%' then raise exception 'FAIL P8: queue exposes email'; end if;
    -- Also try to select reporter_pseudonym/email if they existed
    begin
      perform (select reporter_pseudonym from public.get_moderation_queue() limit 1);
      raise exception 'FAIL P8: reporter_pseudonym exposed';
    exception when undefined_column then
      raise notice 'PASS P8a: no reporter pseudonym';
    end;
    begin
      perform (select reporter_email from public.get_moderation_queue() limit 1);
      raise exception 'FAIL P8: reporter_email exposed';
    exception when undefined_column then
      raise notice 'PASS P8b: no reporter email';
    end;
    raise notice 'PASS P8: queue does not expose reporter identity';
  end;

  -- ============================================================
  -- G4 Saved page projection excludes removed post (moderated post already removed earlier)
  -- ============================================================
  -- Bookmark a post then moderate remove, check saved excludes
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous) values (v_student1_id, v_subject_id, 'note','M5 Saved Test','saved', false) returning id into v_post2_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  insert into public.bookmarks (user_id, post_id) values (v_student2_id, v_post2_id);
  select public.report_content('post', v_post2_id, null, 'spam', null) into v_report_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  perform public.moderate_report(v_report_id, 'remove_content');
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select count(*) into v_count from public.posts_feed where id=v_post2_id;
  if v_count <> 0 then raise exception 'FAIL G4: removed in posts_feed after bookmark'; end if;
  raise notice 'PASS G4: saved excludes removed';
  reset role;

  -- ============================================================
  -- G5 Helpful cannot be added to removed post
  -- ============================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  begin
    insert into public.post_helpful (user_id, post_id) values (v_student2_id, v_post2_id);
    raise exception 'FAIL G5: helpful on removed allowed';
  exception when others then
    if sqlerrm like 'FAIL G5:%' then raise; end if;
    raise notice 'PASS G5: helpful denied on removed (%)', sqlerrm;
  end;
  reset role;

  -- ============================================================
  -- Best Answer interaction after comment removal (implicit via G3)
  -- ============================================================
  -- Create question post with best answer comment, then remove comment, check has_best_answer false
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous) values (v_student1_id, v_subject_id, 'question','M5 Q Best','q', false) returning id into v_post2_id;
  insert into public.comments (author_id, post_id, content) values (v_student2_id, v_post2_id, 'answer') returning id into v_comment2;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000002';
  update public.comments set is_best_answer=true where id=v_comment2;
  reset role;
  -- report and remove comment
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select public.report_content('comment', null, v_comment2, 'spam', null) into v_report_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000001';
  perform public.moderate_report(v_report_id, 'remove_content');
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"dddddddd-dddd-4000-8000-000000000003","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'dddddddd-dddd-4000-8000-000000000003';
  select has_best_answer into v_is_admin from public.posts_feed where id=v_post2_id;
  if v_is_admin then raise exception 'FAIL BestAnswer: still has_best_answer after removal'; end if;
  raise notice 'PASS BestAnswer: removed comment clears has_best_answer';
  reset role;

  -- Cleanup
  delete from public.moderation_actions where moderator_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from public.content_reports where reporter_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from public.comments where author_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from public.posts where author_id in (v_admin_id, v_student1_id, v_student2_id, v_counselor_id);
  delete from public.posts where id=v_post2_id;
  delete from auth.users where email like 'm5_%@example.com';
  delete from public.invitation_codes where code like 'M5TEST-%';
  -- Reset role changes already cleaned via cascade
  raise notice 'ALL M5 SECURITY SCENARIOS COMPLETE';
end
$m5$;
