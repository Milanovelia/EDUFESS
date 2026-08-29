-- ==========================================================================
-- EduFess — M2 social foundation security verification
-- Covers S1-S17 + privacy S20 checks
-- HOW TO RUN: supabase db query --linked --file m2_security_tests.sql
-- ==========================================================================

do $m2$
declare
  v_count int;
  v_name text;
  v_display text;
  v_author uuid;
  v_alias text;
  v_post_id uuid;
  v_post_id2 uuid;
  v_subject_id uuid;
  v_subject2_id uuid;
  v_topic_id uuid;
  v_topic_other uuid;
  v_sub_informatika uuid;
  v_sub_matematika uuid;
begin
  delete from public.posts where author_id in (
    select id from public.profiles where pseudonym like 'M2_%'
  );
  delete from auth.users where email like 'm2_%@example.com';
  delete from public.invitation_codes where code like 'M2TEST-%';

  insert into public.invitation_codes (code) values
    ('M2TEST-CODE-0001'), ('M2TEST-CODE-0002'),
    ('M2TEST-CODE-0003'), ('M2TEST-CODE-0004');

  insert into auth.users (id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data,
                          raw_user_meta_data, created_at, updated_at)
  values ('aaaaaaaa-aaaa-4000-8000-000000000001'::uuid, 'authenticated','authenticated','m2_student1@example.com',
          extensions.crypt('M2-test-pass', extensions.gen_salt('bf')),
          now(),'{"provider":"email","providers":["email"]}',
          jsonb_build_object('pseudonym','M2_Student1','invite_code','M2TEST-CODE-0001'), now(), now());

  insert into auth.users (id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data,
                          raw_user_meta_data, created_at, updated_at)
  values ('aaaaaaaa-aaaa-4000-8000-000000000002'::uuid, 'authenticated','authenticated','m2_student2@example.com',
          extensions.crypt('M2-test-pass', extensions.gen_salt('bf')),
          now(),'{"provider":"email","providers":["email"]}',
          jsonb_build_object('pseudonym','M2_Student2','invite_code','M2TEST-CODE-0002'), now(), now());

  raise notice 'SEED: 2 M2 users created';

  select id into v_sub_informatika from public.subjects where slug='informatika';
  select id into v_sub_matematika from public.subjects where slug='matematika';
  select id into v_topic_id from public.topics where slug='algoritma' and subject_id=v_sub_informatika;
  select id into v_topic_other from public.topics where slug='aljabar' and subject_id=v_sub_matematika;
  if v_sub_informatika is null or v_topic_id is null or v_topic_other is null then
    raise exception 'TEST SETUP FAILED: seed subjects/topics missing';
  end if;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  select count(*) into v_count from public.subjects;
  if v_count < 3 then raise exception 'FAIL S1: authenticated cannot read subjects, count %', v_count; end if;
  raise notice 'PASS S1: authenticated can read subjects (% rows)', v_count;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  begin
    insert into public.subjects (name, slug) values ('Hacked', 'hacked');
    raise exception 'FAIL S2: student created subject';
  exception when others then
    if sqlerrm like 'FAIL S2:%' then raise; end if;
    raise notice 'PASS S2: student cannot create subject -> DENIED (%)', sqlerrm;
  end;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  begin
    update public.subjects set name='Hacked2' where slug='informatika';
    get diagnostics v_count = row_count;
    if v_count <> 0 then raise exception 'FAIL S3: student updated subject, rows %', v_count; end if;
    raise notice 'PASS S3a: student cannot update subject (0 rows)';
  exception when others then
    if sqlerrm like 'FAIL S3:%' then raise; end if;
    raise notice 'PASS S3a: student cannot update subject -> DENIED (%)', sqlerrm;
  end;
  begin
    delete from public.subjects where slug='informatika';
    raise exception 'FAIL S3: student deleted subject';
  exception when others then
    if sqlerrm like 'FAIL S3:%' then raise; end if;
    raise notice 'PASS S3b: student cannot delete subject -> DENIED (%)', sqlerrm;
  end;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  select count(*) into v_count from public.topics;
  if v_count < 8 then raise exception 'FAIL S4: topics count %', v_count; end if;
  raise notice 'PASS S4: authenticated can read topics (% rows)', v_count;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  begin
    insert into public.topics (subject_id, name, slug) values (v_sub_informatika, 'HackedTopic','hacked-topic');
    raise exception 'FAIL S5: student created topic';
  exception when others then
    if sqlerrm like 'FAIL S5:%' then raise; end if;
    raise notice 'PASS S5: student cannot create topic -> DENIED (%)', sqlerrm;
  end;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  begin
    insert into public.posts (author_id, subject_id, topic_id, type, title, content, is_pseudonymous)
    values ('aaaaaaaa-aaaa-4000-8000-000000000001', v_sub_informatika, v_topic_other, 'note','Bad Topic','content', false);
    raise exception 'FAIL S6: mismatched subject/topic allowed';
  exception when others then
    if sqlerrm like 'FAIL S6:%' then raise; end if;
    if sqlerrm ilike '%Topic does not belong%' then
      raise notice 'PASS S6: mismatched subject/topic -> DENIED (%)', sqlerrm;
    else
      raise notice 'PASS S6: mismatched rejected (other error: %)', sqlerrm;
    end if;
  end;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  insert into public.posts (author_id, subject_id, topic_id, type, title, content, is_pseudonymous)
  values ('aaaaaaaa-aaaa-4000-8000-000000000001', v_sub_informatika, v_topic_id, 'note','S7 Public Post','konten S7', false)
  returning id into v_post_id;
  if v_post_id is null then raise exception 'FAIL S7: insert returned null'; end if;
  raise notice 'PASS S7: student can create own post (%)', v_post_id;
  insert into public.posts (author_id, subject_id, topic_id, type, title, content, is_pseudonymous)
  values ('aaaaaaaa-aaaa-4000-8000-000000000001', v_sub_informatika, null, 'question','S7 Anon Post','konten anon', true)
  returning id into v_post_id2;
  raise notice 'PASS S7b: pseudonymous post created (%)', v_post_id2;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous)
  values ('aaaaaaaa-aaaa-4000-8000-000000000002', v_sub_informatika, 'tip','Spoof Post','konten spoof', false)
  returning id, author_id into v_post_id, v_author;
  select author_id into v_author from public.posts where id = v_post_id;
  if v_author = 'aaaaaaaa-aaaa-4000-8000-000000000002'::uuid then
    raise exception 'FAIL S8: spoofed author_id persisted';
  end if;
  if v_author <> 'aaaaaaaa-aaaa-4000-8000-000000000001'::uuid then
    raise exception 'FAIL S8: author not forced to own, got %', v_author;
  end if;
  raise notice 'PASS S8: spoof author_id forced to own (%)', v_author;
  reset role;
  delete from public.posts where id = v_post_id;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  select id into v_post_id from public.posts where author_id='aaaaaaaa-aaaa-4000-8000-000000000001' and title like 'S7 Public%' limit 1;
  update public.posts set title='S7 Public Post Edited' where id = v_post_id;
  get diagnostics v_count = row_count;
  if v_count <> 1 then raise exception 'FAIL S9: cannot update own post, rows %', v_count; end if;
  raise notice 'PASS S9: student can update own post';
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000002';
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous)
  values ('aaaaaaaa-aaaa-4000-8000-000000000002', v_sub_informatika, 'note','Other Post','other content', false)
  returning id into v_post_id2;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  update public.posts set title='Hacked Title' where id = v_post_id2;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'FAIL S10: student updated other post, rows %', v_count; end if;
  raise notice 'PASS S10: student cannot update other post (0 rows)';
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  select id into v_post_id from public.posts where author_id='aaaaaaaa-aaaa-4000-8000-000000000001' and deleted_at is null limit 1;
  update public.posts set deleted_at = now() where id = v_post_id;
  get diagnostics v_count = row_count;
  if v_count <> 1 then raise exception 'FAIL S11: soft-delete own failed'; end if;
  raise notice 'PASS S11: student can soft-delete own post';
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  update public.posts set deleted_at = now() where id = v_post_id2;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'FAIL S12: student soft-deleted other post'; end if;
  raise notice 'PASS S12: student cannot soft-delete other post (0 rows)';
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous)
  values ('aaaaaaaa-aaaa-4000-8000-000000000001', v_sub_informatika, 'question','S13 Anon','anon content', true)
  returning id, anonymous_alias into v_post_id, v_alias;
  select author_id, anonymous_alias into v_author, v_alias from public.posts where id = v_post_id;
  if v_author <> 'aaaaaaaa-aaaa-4000-8000-000000000001'::uuid then raise exception 'FAIL S13: author_id not retained'; end if;
  if v_alias is null or v_alias not ilike 'Siswa Anonim #%' then raise exception 'FAIL S13: alias not generated (%)', v_alias; end if;
  raise notice 'PASS S13: pseudonymous retains author_id + alias %', v_alias;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000002';
  select display_author into v_display from public.posts_feed where id = v_post_id;
  if v_display = 'M2_Student1' then raise exception 'FAIL S14: feed exposed real pseudonym'; end if;
  if v_display not ilike 'Siswa Anonim #%' then raise exception 'FAIL S14: display_author not alias, got %', v_display; end if;
  raise notice 'PASS S14: pseudonymous feed display_author is alias (%)', v_display;
  reset role;

  if exists (select 1 from information_schema.columns where table_name='posts_feed' and column_name='email') then
    raise exception 'FAIL S15: posts_feed has email column';
  end if;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000002';
  perform * from public.posts_feed where id = v_post_id;
  raise notice 'PASS S15: posts_feed has no email column';
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  insert into public.posts (author_id, subject_id, type, title, content, is_pseudonymous)
  values ('aaaaaaaa-aaaa-4000-8000-000000000001', v_sub_informatika, 'note','S16 Public','public content', false)
  returning id into v_post_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000002';
  select display_author into v_display from public.posts_feed where id = v_post_id;
  if v_display <> 'M2_Student1' then raise exception 'FAIL S16: public display_author mismatch, got %', v_display; end if;
  raise notice 'PASS S16: public post display_author = pseudonym (%)', v_display;
  reset role;

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000001","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000001';
  update public.posts set deleted_at = now() where id = v_post_id;
  reset role;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000002';
  select count(*) into v_count from public.posts_feed where id = v_post_id;
  if v_count <> 0 then raise exception 'FAIL S17: deleted post still in feed'; end if;
  raise notice 'PASS S17: deleted post excluded from feed';
  reset role;

  select count(*) into v_count from public.posts where id = v_post_id and deleted_at is not null;
  if v_count <> 1 then raise exception 'FAIL S17b: deleted post not retain in base table'; end if;
  raise notice 'PASS S17b: deleted post retained with deleted_at';

  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"aaaaaaaa-aaaa-4000-8000-000000000002","role":"authenticated"}';
  set local "request.jwt.claim.sub" = 'aaaaaaaa-aaaa-4000-8000-000000000002';
  select count(*) into v_count from public.posts p join public.profiles pr on pr.id = p.author_id
    where p.is_pseudonymous = true and p.deleted_at is null;
  if v_count <> 0 then
    raise exception 'FAIL S20: student resolved pseudonymous author via direct join, count %', v_count;
  end if;
  raise notice 'PASS S20: pseudonymous identity not resolvable via direct join (0 rows)';
  select count(*) into v_count from public.profiles where id='aaaaaaaa-aaaa-4000-8000-000000000002';
  if v_count <> 1 then raise exception 'FAIL S20b: own profile not accessible'; end if;
  raise notice 'PASS S20b: own profile still accessible';
  reset role;

  select count(*) into v_count from pg_policies where tablename='posts' and policyname='posts_select_active';
  if v_count <> 1 then raise exception 'FAIL grants: posts_select_active missing'; end if;
  select count(*) into v_count from pg_class where relname='posts_feed' and 'security_invoker=false' = any(reloptions);
  if v_count <> 1 then raise exception 'FAIL grants: posts_feed not security_invoker=false'; end if;
  raise notice 'PASS grants: RLS + view security_invoker correct';

  delete from public.posts where author_id in ('aaaaaaaa-aaaa-4000-8000-000000000001','aaaaaaaa-aaaa-4000-8000-000000000002');
  delete from auth.users where email like 'm2_%@example.com';
  delete from public.invitation_codes where code like 'M2TEST-%';

  raise notice 'ALL M2 SECURITY SCENARIOS COMPLETE';
end
$m2$;
