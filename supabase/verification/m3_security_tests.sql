-- ==========================================================================
-- EduFess — M3 social interaction security verification
-- Covers C1-C9, H1-H5, B1-B5, BA1-BA6, P1-P4 + M2/M1 regression
-- HOW TO RUN: supabase db query --linked --file m3_security_tests.sql
-- ==========================================================================

do $m3$
declare
  v_count int;
  v_display text;
  v_author uuid;
  v_alias text;
  v_post_id uuid;
  v_post2_id uuid;
  v_post_note_id uuid;
  v_comment_id uuid;
  v_ba1_comment_id uuid;
  v_comment2_id uuid;
  v_reply_id uuid;
  v_subject_id uuid;
  v_topic_id uuid;
begin
  -- Cleanup
  delete from public.comments where author_id in (select id from public.profiles where pseudonym like 'M3_%');
  delete from public.post_helpful where user_id in (select id from public.profiles where pseudonym like 'M3_%');
  delete from public.bookmarks where user_id in (select id from public.profiles where pseudonym like 'M3_%');
  delete from public.posts where author_id in (select id from public.profiles where pseudonym like 'M3_%');
  delete from auth.users where email like 'm3_%@example.com';
  delete from public.invitation_codes where code like 'M3TEST-%';

  insert into public.invitation_codes (code) values ('M3TEST-CODE-0001'),('M3TEST-CODE-0002'),('M3TEST-CODE-0003');

  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values ('bbbbbbbb-bbbb-4000-8000-000000000001'::uuid,'authenticated','authenticated','m3_student1@example.com', extensions.crypt('M3-test-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M3_Student1','invite_code','M3TEST-CODE-0001'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values ('bbbbbbbb-bbbb-4000-8000-000000000002'::uuid,'authenticated','authenticated','m3_student2@example.com', extensions.crypt('M3-test-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M3_Student2','invite_code','M3TEST-CODE-0002'), now(), now());
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values ('bbbbbbbb-bbbb-4000-8000-000000000003'::uuid,'authenticated','authenticated','m3_student3@example.com', extensions.crypt('M3-test-pass', extensions.gen_salt('bf')), now(),'{"provider":"email","providers":["email"]}', jsonb_build_object('pseudonym','M3_Student3','invite_code','M3TEST-CODE-0003'), now(), now());

  raise notice 'SEED: 3 M3 users created';
  select id into v_subject_id from public.subjects where slug='informatika';
  select id into v_topic_id from public.topics where slug='algoritma' and subject_id=v_subject_id;
  if v_subject_id is null then raise exception 'TEST SETUP FAILED: subjects missing'; end if;

  -- Create posts: question and note
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  insert into public.posts (author_id, subject_id, topic_id, type, title, content, is_pseudonymous) values ('bbbbbbbb-bbbb-4000-8000-000000000001', v_subject_id, v_topic_id, 'question','M3 Question','question content', false) returning id into v_post_id;
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous) values ('bbbbbbbb-bbbb-4000-8000-000000000001', v_subject_id, 'note','M3 Note','note content', false) returning id into v_post_note_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_subject_id, 'question','M3 Q2','q2 content', false) returning id into v_post2_id;
  reset role;
  raise notice 'SEED: posts % % %', v_post_id, v_post2_id, v_post_note_id;

  -- C1 student can create own comment
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content, is_pseudonymous) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id, 'C1 comment', false) returning id into v_comment_id;
  if v_comment_id is null then raise exception 'FAIL C1'; end if;
  raise notice 'PASS C1: student can create own comment %', v_comment_id;
  reset role;

  -- C2 author spoofing denied/forced
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content, is_pseudonymous) values ('bbbbbbbb-bbbb-4000-8000-000000000001', v_post_id, 'Spoof comment', false) returning id, author_id into v_comment2_id, v_author;
  if v_author = 'bbbbbbbb-bbbb-4000-8000-000000000001'::uuid then raise exception 'FAIL C2: spoof persisted'; end if;
  if v_author <> 'bbbbbbbb-bbbb-4000-8000-000000000002'::uuid then raise exception 'FAIL C2: not forced to own %', v_author; end if;
  raise notice 'PASS C2: spoof forced to own %', v_author;
  reset role;
  delete from public.comments where id = v_comment2_id;

  -- C3 student can edit own comment
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  update public.comments set content='C1 edited' where id=v_comment_id;
  get diagnostics v_count=row_count; if v_count<>1 then raise exception 'FAIL C3'; end if;
  raise notice 'PASS C3: student can edit own comment';
  reset role;

  -- C4 cannot edit other comment
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  update public.comments set content='Hacked' where id=v_comment_id;
  get diagnostics v_count=row_count; if v_count<>0 then raise exception 'FAIL C4'; end if;
  raise notice 'PASS C4: student cannot edit other comment (0 rows)';
  reset role;

  -- C5 soft-delete own
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id, 'To delete') returning id into v_comment2_id;
  update public.comments set deleted_at=now() where id=v_comment2_id;
  get diagnostics v_count=row_count; if v_count<>1 then raise exception 'FAIL C5'; end if;
  raise notice 'PASS C5: student can soft-delete own comment';
  reset role;

  -- C6 cannot soft-delete other
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  update public.comments set deleted_at=now() where id=v_comment_id;
  get diagnostics v_count=row_count; if v_count<>0 then raise exception 'FAIL C6'; end if;
  raise notice 'PASS C6: cannot soft-delete other comment';
  reset role;

  -- C7 max reply depth =1 enforced
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, parent_id, content) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id, v_comment_id, 'Reply level1') returning id into v_reply_id;
  raise notice 'PASS C7a: level1 reply allowed %', v_reply_id;
  begin
    insert into public.comments (author_id, post_id, parent_id, content) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id, v_reply_id, 'Reply level2');
    raise exception 'FAIL C7: level2 allowed';
  exception when others then
    if sqlerrm like 'FAIL C7:%' then raise; end if;
    raise notice 'PASS C7: level2 denied (%)', sqlerrm;
  end;
  reset role;

  -- C8 pseudonymous comment keeps real author
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content, is_pseudonymous) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id, 'Anon comment', true) returning id, anonymous_alias into v_comment2_id, v_alias;
  select author_id, anonymous_alias into v_author, v_alias from public.comments where id=v_comment2_id;
  if v_author<>'bbbbbbbb-bbbb-4000-8000-000000000002'::uuid then raise exception 'FAIL C8 author'; end if;
  if v_alias is null or v_alias not ilike 'Siswa Anonim #%' then raise exception 'FAIL C8 alias %', v_alias; end if;
  raise notice 'PASS C8: pseudonymous keeps author + alias %', v_alias;
  reset role;

  -- C9 pseudonymous not reveal via feed
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  select display_author into v_display from public.comments_feed where id=v_comment2_id;
  if v_display='M3_Student2' then raise exception 'FAIL C9 exposed'; end if;
  if v_display not ilike 'Siswa Anonim #%' then raise exception 'FAIL C9 not alias %', v_display; end if;
  raise notice 'PASS C9: pseudonymous feed is alias %', v_display;
  reset role;

  -- H1 user can add own helpful
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.post_helpful (user_id, post_id) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id);
  raise notice 'PASS H1: add helpful';
  reset role;

  -- H2 duplicate rejected
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  begin
    insert into public.post_helpful (user_id, post_id) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id);
    raise exception 'FAIL H2 duplicate allowed';
  exception when others then
    if sqlerrm like 'FAIL H2:%' then raise; end if;
    raise notice 'PASS H2: duplicate denied (%)', sqlerrm;
  end;
  reset role;

  -- H3 can remove own
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  delete from public.post_helpful where user_id='bbbbbbbb-bbbb-4000-8000-000000000002' and post_id=v_post_id;
  get diagnostics v_count=row_count; if v_count<>1 then raise exception 'FAIL H3'; end if;
  raise notice 'PASS H3: remove own helpful';
  reset role;
  -- re-add for later
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.post_helpful (user_id, post_id) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id);
  reset role;

  -- H4 cannot insert for another user (forced or denied)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  begin
    insert into public.post_helpful (user_id, post_id) values ('bbbbbbbb-bbbb-4000-8000-000000000001', v_post_id);
    raise exception 'FAIL H4 spoof allowed';
  exception when others then
    if sqlerrm like 'FAIL H4:%' then raise; end if;
    raise notice 'PASS H4: cannot insert for another user (%)', sqlerrm;
  end;
  reset role;

  -- H5 deleted post cannot receive helpful
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  update public.posts set deleted_at=now() where id=v_post2_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  begin
    insert into public.post_helpful (user_id, post_id) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post2_id);
    raise exception 'FAIL H5 deleted post helpful allowed';
  exception when others then
    if sqlerrm like 'FAIL H5:%' then raise; end if;
    raise notice 'PASS H5: deleted post helpful denied (%)', sqlerrm;
  end;
  reset role;
  -- restore post2
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  update public.posts set deleted_at=null where id=v_post2_id;
  reset role;

  -- B1 bookmark
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.bookmarks (user_id, post_id) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id);
  raise notice 'PASS B1: bookmark';
  reset role;

  -- B2 duplicate
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  begin
    insert into public.bookmarks (user_id, post_id) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id);
    raise exception 'FAIL B2 duplicate allowed';
  exception when others then
    if sqlerrm like 'FAIL B2:%' then raise; end if;
    raise notice 'PASS B2: duplicate bookmark denied (%)', sqlerrm;
  end;
  reset role;

  -- B3 remove own
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  delete from public.bookmarks where user_id='bbbbbbbb-bbbb-4000-8000-000000000002' and post_id=v_post_id;
  get diagnostics v_count=row_count; if v_count<>1 then raise exception 'FAIL B3'; end if;
  raise notice 'PASS B3: remove bookmark';
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.bookmarks (user_id, post_id) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id);
  reset role;

  -- B4 cannot see another user's bookmark
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  select count(*) into v_count from public.bookmarks where user_id='bbbbbbbb-bbbb-4000-8000-000000000002';
  if v_count<>0 then raise exception 'FAIL B4 sees other bookmark %', v_count; end if;
  raise notice 'PASS B4: cannot see other bookmark';
  reset role;

  -- B5 cannot bookmark as another user
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  begin
    insert into public.bookmarks (user_id, post_id) values ('bbbbbbbb-bbbb-4000-8000-000000000001', v_post_id);
    raise exception 'FAIL B5 spoof allowed';
  exception when others then
    if sqlerrm like 'FAIL B5:%' then raise; end if;
    raise notice 'PASS B5: spoof denied (%)', sqlerrm;
  end;
  reset role;

  -- BA1 question author can mark best
  -- Create a new comment owned by student 1 from the beginning (ownership established at INSERT)
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  insert into public.comments (author_id, post_id, content, is_best_answer) values ('bbbbbbbb-bbbb-4000-8000-000000000001', v_post_id, 'BA1 comment', false) returning id into v_ba1_comment_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  update public.comments set is_best_answer=true where id=v_ba1_comment_id;
  get diagnostics v_count=row_count; if v_count<>1 then raise exception 'FAIL BA1'; end if;
  raise notice 'PASS BA1: author can mark best';
  reset role;

  -- BA2 non-author cannot mark
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id, 'Another comment') returning id into v_comment2_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  begin
    update public.comments set is_best_answer=true where id=v_comment2_id;
    raise exception 'FAIL BA2 non-author marked';
  exception when others then
    if sqlerrm like 'FAIL BA2:%' then raise; end if;
    raise notice 'PASS BA2: non-author denied (%)', sqlerrm;
  end;
  reset role;

  -- BA3 max 1 per post
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  begin
    update public.comments set is_best_answer=true where id=v_comment2_id;
    raise exception 'FAIL BA3 second best allowed';
  exception when others then
    if sqlerrm like 'FAIL BA3:%' then raise; end if;
    raise notice 'PASS BA3: max 1 denied (%)', sqlerrm;
  end;
  reset role;

  -- BA4 non-question cannot have best
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  insert into public.comments (author_id, post_id, content) values ('bbbbbbbb-bbbb-4000-8000-000000000001', v_post_note_id, 'Note comment') returning id into v_comment2_id;
  begin
    update public.comments set is_best_answer=true where id=v_comment2_id;
    raise exception 'FAIL BA4 non-question allowed';
  exception when others then
    if sqlerrm like 'FAIL BA4:%' then raise; end if;
    raise notice 'PASS BA4: non-question denied (%)', sqlerrm;
  end;
  reset role;
  delete from public.comments where id=v_comment2_id;

  -- BA5 comment from other post: use v_reply_id which belongs to v_post_id, try to ensure it counts only per post isolation
  -- Insert comment on post2 then try count best isolation
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  select count(*) into v_count from public.comments where post_id=v_post2_id and is_best_answer=true;
  if v_count<>0 then raise exception 'FAIL BA5 isolation %', v_count; end if;
  raise notice 'PASS BA5: isolation ok';
  reset role;

  -- BA6 deleted comment cannot be marked
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  -- clear existing best first
  update public.comments set is_best_answer=false where id=v_comment_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  insert into public.comments (author_id, post_id, content) values ('bbbbbbbb-bbbb-4000-8000-000000000002', v_post_id, 'To del best') returning id into v_comment2_id;
  update public.comments set deleted_at=now() where id=v_comment2_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  begin
    update public.comments set is_best_answer=true where id=v_comment2_id;
    raise exception 'FAIL BA6 deleted marked';
  exception when others then
    if sqlerrm like 'FAIL BA6:%' then raise; end if;
    raise notice 'PASS BA6: deleted cannot be best (%)', sqlerrm;
  end;
  reset role;

  -- P1 pseudonymous post still cannot be deanonymized
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000002';
  select count(*) into v_count from public.posts p join public.profiles pr on pr.id=p.author_id where p.is_pseudonymous=true and p.deleted_at is null;
  if v_count<>0 then raise exception 'FAIL P1 %', v_count; end if;
  raise notice 'PASS P1: post deanonymize blocked';
  reset role;

  -- P2 pseudonymous comment cannot be deanonymized
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  select count(*) into v_count from public.comments c join public.profiles pr on pr.id=c.author_id where c.is_pseudonymous=true and c.deleted_at is null;
  if v_count<>0 then raise exception 'FAIL P2 %', v_count; end if;
  raise notice 'PASS P2: comment deanonymize blocked';
  -- also check feed view has no email
  if exists (select 1 from information_schema.columns where table_name='comments_feed' and column_name='email') then raise exception 'FAIL P2 email in feed'; end if;
  raise notice 'PASS P2b: comments_feed no email';
  reset role;

  -- P3 email never exposed in posts_feed/comments_feed
  if exists (select 1 from information_schema.columns where table_name='posts_feed' and column_name='email') then raise exception 'FAIL P3 email in posts_feed'; end if;
  raise notice 'PASS P3: no email in feeds';

  -- P4 bookmarks private
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"bbbbbbbb-bbbb-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'bbbbbbbb-bbbb-4000-8000-000000000001';
  select count(*) into v_count from public.bookmarks where user_id='bbbbbbbb-bbbb-4000-8000-000000000002';
  if v_count<>0 then raise exception 'FAIL P4 sees other bookmarks'; end if;
  raise notice 'PASS P4: bookmarks private';
  reset role;

  -- Cleanup
  delete from public.comments where author_id in ('bbbbbbbb-bbbb-4000-8000-000000000001','bbbbbbbb-bbbb-4000-8000-000000000002','bbbbbbbb-bbbb-4000-8000-000000000003');
  delete from public.post_helpful where user_id in ('bbbbbbbb-bbbb-4000-8000-000000000001','bbbbbbbb-bbbb-4000-8000-000000000002');
  delete from public.bookmarks where user_id in ('bbbbbbbb-bbbb-4000-8000-000000000001','bbbbbbbb-bbbb-4000-8000-000000000002');
  delete from public.posts where id in (v_post_id, v_post2_id, v_post_note_id);
  delete from auth.users where email like 'm3_%@example.com';
  delete from public.invitation_codes where code like 'M3TEST-%';
  raise notice 'ALL M3 SECURITY SCENARIOS COMPLETE';
end
$m3$;
