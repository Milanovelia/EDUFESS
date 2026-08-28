-- ==========================================================================
-- EduFess — M1 C1 security verification (auth repair version)
--
-- Auth model: email+password = Supabase Auth (PRIVATE), pseudonym = PUBLIC
-- identity, invitation code = registration gate. No synthetic email, no
-- custom domain required.
--
-- HOW TO RUN
--   supabase db query --linked --file c1_security_tests.sql
--   Or Supabase Dashboard > SQL Editor (as `postgres`).
-- ==========================================================================

-- All tests in one DO block to prevent role leaking across transactions.
do $all$
declare
  v_name  text;
  v_count int;
  v_role  text;
  v_id    uuid;
begin
  -- =======================================================================
  -- CLEANUP
  -- =======================================================================
  delete from auth.users where email like 'test_%@example.com';
  delete from public.invitation_codes where code like 'C1TEST-%';

  -- =======================================================================
  -- SEED invitation codes
  -- =======================================================================
  insert into public.invitation_codes (code) values
    ('C1TEST-CODE-0001'),
    ('C1TEST-CODE-0002'),
    ('C1TEST-CODE-0003'),
    ('C1TEST-CODE-0004'),
    ('C1TEST-CODE-0100');

  -- =======================================================================
  -- SEED 4 users through the real trigger pipeline.
  -- =======================================================================
  v_id := '00000000-0000-4000-8000-000000000001'::uuid;
  insert into auth.users (id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data,
                          raw_user_meta_data, created_at, updated_at)
  values (v_id, 'authenticated', 'authenticated', 'test_student1@example.com',
          extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
          now(), '{"provider":"email","providers":["email"]}',
          jsonb_build_object('pseudonym', 'Student_1', 'invite_code', 'C1TEST-CODE-0001'),
          now(), now());

  v_id := '00000000-0000-4000-8000-000000000002'::uuid;
  insert into auth.users (id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data,
                          raw_user_meta_data, created_at, updated_at)
  values (v_id, 'authenticated', 'authenticated', 'test_student2@example.com',
          extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
          now(), '{"provider":"email","providers":["email"]}',
          jsonb_build_object('pseudonym', 'Student_2', 'invite_code', 'C1TEST-CODE-0002'),
          now(), now());

  v_id := '00000000-0000-4000-8000-000000000003'::uuid;
  insert into auth.users (id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data,
                          raw_user_meta_data, created_at, updated_at)
  values (v_id, 'authenticated', 'authenticated', 'test_counsel1@example.com',
          extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
          now(), '{"provider":"email","providers":["email"]}',
          jsonb_build_object('pseudonym', 'Counsel_1', 'invite_code', 'C1TEST-CODE-0003'),
          now(), now());

  v_id := '00000000-0000-4000-8000-000000000004'::uuid;
  insert into auth.users (id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data,
                          raw_user_meta_data, created_at, updated_at)
  values (v_id, 'authenticated', 'authenticated', 'test_admin1@example.com',
          extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
          now(), '{"provider":"email","providers":["email"]}',
          jsonb_build_object('pseudonym', 'Admin_1', 'invite_code', 'C1TEST-CODE-0004'),
          now(), now());

  -- Operator role provisioning
  update public.profiles set role = 'counselor'
    where id = '00000000-0000-4000-8000-000000000003';
  update public.profiles set role = 'admin'
    where id = '00000000-0000-4000-8000-000000000004';
  raise notice 'SEED: 4 users + role provisioning done';

  -- =======================================================================
  -- INV-02: Signup without invitation code -> DENIED
  -- =======================================================================
  begin
    insert into auth.users (id, aud, role, email, encrypted_password,
                            email_confirmed_at, raw_app_meta_data,
                            raw_user_meta_data, created_at, updated_at)
    values ('00000000-0000-4000-8000-000000000005'::uuid, 'authenticated',
            'authenticated', 'test_nocode@example.com',
            extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
            now(), '{"provider":"email","providers":["email"]}',
            jsonb_build_object('pseudonym', 'Gate_User'),
            now(), now());
    raise exception 'TEST FAILED: signup without invitation code allowed';
  exception
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS INV-02: signup without invitation code -> DENIED (%)', sqlerrm;
  end;

  -- =======================================================================
  -- INV-03: Valid code -> student profile + code bound; reuse -> DENIED
  -- =======================================================================
  v_id := '00000000-0000-4000-8000-000000000006'::uuid;
  insert into auth.users (id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data,
                          raw_user_meta_data, created_at, updated_at)
  values (v_id, 'authenticated', 'authenticated', 'test_invite@example.com',
          extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
          now(), '{"provider":"email","providers":["email"]}',
          jsonb_build_object('pseudonym', 'Invite_User', 'invite_code', 'C1TEST-CODE-0100'),
          now(), now());

  select count(*) into v_count from public.profiles
    where id = v_id and role = 'student';
  if v_count <> 1 then
    raise exception 'TEST FAILED: invited signup did not create student profile';
  end if;

  select count(*) into v_count from public.invitation_codes
    where code = 'C1TEST-CODE-0100' and used_by = v_id and used_at is not null;
  if v_count <> 1 then
    raise exception 'TEST FAILED: invitation not bound to new profile';
  end if;
  raise notice 'PASS INV-03a: invited signup -> student profile + invitation bound';

  begin
    insert into auth.users (id, aud, role, email, encrypted_password,
                            email_confirmed_at, raw_app_meta_data,
                            raw_user_meta_data, created_at, updated_at)
    values ('00000000-0000-4000-8000-000000000007'::uuid, 'authenticated',
            'authenticated', 'test_reuse@example.com',
            extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
            now(), '{"provider":"email","providers":["email"]}',
            jsonb_build_object('pseudonym', 'Invite_User2', 'invite_code', 'C1TEST-CODE-0100'),
            now(), now());
    raise exception 'TEST FAILED: invitation code reuse allowed';
  exception
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS INV-03b: invitation code reuse -> DENIED (%)', sqlerrm;
  end;

  -- =======================================================================
  -- INV-04: Signup always creates student
  -- =======================================================================
  insert into public.invitation_codes (code) values ('C1TEST-CODE-INV04');
  v_id := '00000000-0000-4000-8000-000000000008'::uuid;
  insert into auth.users (id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data,
                          raw_user_meta_data, created_at, updated_at)
  values (v_id, 'authenticated', 'authenticated', 'test_role@example.com',
          extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
          now(), '{"provider":"email","providers":["email"]}',
          jsonb_build_object('pseudonym', 'Role_User', 'invite_code', 'C1TEST-CODE-INV04'),
          now(), now());

  select role into v_role from public.profiles where id = v_id;
  if v_role <> 'student' then
    raise exception 'TEST FAILED: signup did not create student role, got %', v_role;
  end if;
  raise notice 'PASS INV-04: signup always creates student role';

  -- =======================================================================
  -- INV-06: Pseudonym uniqueness enforced server-side
  -- =======================================================================
  begin
    insert into public.invitation_codes (code) values ('C1TEST-CODE-INV06A');
    insert into auth.users (id, aud, role, email, encrypted_password,
                            email_confirmed_at, raw_app_meta_data,
                            raw_user_meta_data, created_at, updated_at)
    values (gen_random_uuid(), 'authenticated', 'authenticated', 'test_unique1@example.com',
            extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
            now(), '{"provider":"email","providers":["email"]}',
            jsonb_build_object('pseudonym', 'Unique_User', 'invite_code', 'C1TEST-CODE-INV06A'),
            now(), now());

    begin
      insert into public.invitation_codes (code) values ('C1TEST-CODE-INV06B');
      insert into auth.users (id, aud, role, email, encrypted_password,
                              email_confirmed_at, raw_app_meta_data,
                              raw_user_meta_data, created_at, updated_at)
      values (gen_random_uuid(), 'authenticated', 'authenticated', 'test_unique2@example.com',
              extensions.crypt('C1-test-password', extensions.gen_salt('bf')),
              now(), '{"provider":"email","providers":["email"]}',
              jsonb_build_object('pseudonym', 'unique_user', 'invite_code', 'C1TEST-CODE-INV06B'),
              now(), now());
      raise exception 'TEST FAILED: duplicate pseudonym allowed';
    exception
      when others then
        if sqlerrm like 'TEST FAILED:%' then raise; end if;
        raise notice 'PASS INV-06: duplicate pseudonym -> DENIED (%)', sqlerrm;
    end;
  end;

  -- =======================================================================
  -- INV-07/08: Email privacy — profiles table has no email column
  -- =======================================================================
  if exists(
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'email'
  ) then
    raise exception 'TEST FAILED: profiles table contains email column';
  end if;
  raise notice 'PASS INV-07/08: profiles has no email column (email stays private)';

  -- =======================================================================
  -- T9-A anon: SELECT / INSERT / UPDATE / DELETE all DENIED
  -- =======================================================================
  reset role;

  begin
    set local role anon;
    perform id from public.profiles;
    raise exception 'TEST FAILED: anon SELECT profiles allowed';
  exception
    when insufficient_privilege then
      raise notice 'PASS T9-A: anon SELECT profiles -> DENIED';
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS T9-A: anon SELECT profiles -> DENIED (%)', sqlerrm;
  end;
  reset role;

  begin
    set local role anon;
    insert into public.profiles (id, pseudonym) values (gen_random_uuid(), 'Anon_User');
    raise exception 'TEST FAILED: anon INSERT profiles allowed';
  exception
    when insufficient_privilege then
      raise notice 'PASS T9-A: anon INSERT profiles -> DENIED';
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS T9-A: anon INSERT profiles -> DENIED (%)', sqlerrm;
  end;
  reset role;

  begin
    set local role anon;
    update public.profiles set role = 'admin';
    raise exception 'TEST FAILED: anon UPDATE profiles allowed';
  exception
    when insufficient_privilege then
      raise notice 'PASS T9-A: anon UPDATE profiles -> DENIED';
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS T9-A: anon UPDATE profiles -> DENIED (%)', sqlerrm;
  end;
  reset role;

  begin
    set local role anon;
    delete from public.profiles;
    raise exception 'TEST FAILED: anon DELETE profiles allowed';
  exception
    when insufficient_privilege then
      raise notice 'PASS T9-A: anon DELETE profiles -> DENIED';
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS T9-A: anon DELETE profiles -> DENIED (%)', sqlerrm;
  end;
  reset role;

  -- =======================================================================
  -- T9-B student scenarios
  -- =======================================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}';

  -- SELECT own profile -> ALLOWED
  select pseudonym into v_name from public.profiles
    where id = '00000000-0000-4000-8000-000000000001';
  if v_name is null then
    raise exception 'TEST FAILED: student cannot SELECT own profile';
  end if;
  if v_name <> 'Student_1' then
    raise exception 'TEST FAILED: student SELECT own returned wrong row (%)', v_name;
  end if;
  raise notice 'PASS T9-B: student SELECT own profile -> ALLOWED';

  -- SELECT another profile -> DENIED (0 rows via RLS)
  select count(*) into v_count from public.profiles
    where id = '00000000-0000-4000-8000-000000000002';
  if v_count <> 0 then
    raise exception 'TEST FAILED: student saw another user profile';
  end if;
  raise notice 'PASS T9-B: student SELECT another profile -> DENIED (0 rows)';

  -- UPDATE own role -> DENIED
  begin
    update public.profiles set role = 'admin'
      where id = '00000000-0000-4000-8000-000000000001';
    raise exception 'TEST FAILED: student escalated own role to admin';
  exception
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS T9-B: student role escalation -> DENIED (%)', sqlerrm;
  end;

  -- UPDATE own pseudonym -> DENIED
  begin
    update public.profiles set pseudonym = 'Student_1X'
      where id = '00000000-0000-4000-8000-000000000001';
    raise exception 'TEST FAILED: student changed immutable pseudonym';
  exception
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS T9-B: student pseudonym change -> DENIED (%)', sqlerrm;
  end;

  -- UPDATE own row, no-op -> ALLOWED
  update public.profiles set updated_at = updated_at
    where id = '00000000-0000-4000-8000-000000000001';
  get diagnostics v_count = row_count;
  if v_count <> 1 then
    raise exception 'TEST FAILED: student no-op own UPDATE blocked';
  end if;
  raise notice 'PASS T9-B: student UPDATE own row (no-op) -> ALLOWED';

  -- UPDATE another profile -> DENIED (0 rows via RLS)
  update public.profiles set role = 'admin'
    where id = '00000000-0000-4000-8000-000000000002';
  get diagnostics v_count = row_count;
  if v_count <> 0 then
    raise exception 'TEST FAILED: student updated another user profile';
  end if;
  raise notice 'PASS T9-B: student UPDATE another profile -> DENIED (0 rows)';

  -- DELETE -> DENIED
  begin
    delete from public.profiles;
    raise exception 'TEST FAILED: student DELETE allowed';
  exception
    when insufficient_privilege then
      raise notice 'PASS T9-B: student DELETE -> DENIED';
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS T9-B: student DELETE -> DENIED (%)', sqlerrm;
  end;

  reset role;

  -- =======================================================================
  -- T9-C counselor spot checks
  -- =======================================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"00000000-0000-4000-8000-000000000003","role":"authenticated"}';

  select count(*) into v_count from public.profiles
    where id = '00000000-0000-4000-8000-000000000003' and role = 'counselor';
  if v_count <> 1 then
    raise exception 'TEST FAILED: counselor cannot SELECT own profile';
  end if;
  raise notice 'PASS T9-C: counselor SELECT own profile -> ALLOWED';

  select count(*) into v_count from public.profiles
    where id = '00000000-0000-4000-8000-000000000001';
  if v_count <> 0 then
    raise exception 'TEST FAILED: counselor saw another user profile';
  end if;
  raise notice 'PASS T9-C: counselor SELECT another profile -> DENIED (0 rows)';

  begin
    update public.profiles set role = 'admin'
      where id = '00000000-0000-4000-8000-000000000003';
    raise exception 'TEST FAILED: counselor escalated own role to admin';
  exception
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS T9-C: counselor role escalation -> DENIED (%)', sqlerrm;
  end;

  reset role;

  -- =======================================================================
  -- T9-D admin spot checks
  -- =======================================================================
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub":"00000000-0000-4000-8000-000000000004","role":"authenticated"}';

  select count(*) into v_count from public.profiles
    where id = '00000000-0000-4000-8000-000000000004' and role = 'admin';
  if v_count <> 1 then
    raise exception 'TEST FAILED: admin cannot SELECT own profile';
  end if;
  raise notice 'PASS T9-D: admin SELECT own profile -> ALLOWED';

  select count(*) into v_count from public.profiles
    where id = '00000000-0000-4000-8000-000000000001';
  if v_count <> 0 then
    raise exception 'TEST FAILED: admin saw another user profile';
  end if;
  raise notice 'PASS T9-D: admin SELECT another profile -> DENIED (0 rows)';

  begin
    update public.profiles set pseudonym = 'Admin_1X'
      where id = '00000000-0000-4000-8000-000000000004';
    raise exception 'TEST FAILED: admin changed immutable pseudonym via API';
  exception
    when others then
      if sqlerrm like 'TEST FAILED:%' then raise; end if;
      raise notice 'PASS T9-D: admin pseudonym change via client -> DENIED (%)', sqlerrm;
  end;

  reset role;

  -- =======================================================================
  -- CLEANUP
  -- =======================================================================
  delete from auth.users where email like 'test_%@example.com';
  delete from public.invitation_codes where code like 'C1TEST-%';

  raise notice 'ALL C1 SECURITY SCENARIOS COMPLETE';
end
$all$;
