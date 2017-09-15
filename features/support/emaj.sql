CREATE EXTENSION dblink;
CREATE EXTENSION emaj;
INSERT INTO emaj.emaj_group_def (grpdef_group, grpdef_schema, grpdef_tblseq)
  VALUES ('system-test', 'public', 'organizational_units'),
         ('system-test', 'public', 'organizations'),
         ('system-test', 'public', 'repositories'),
         ('system-test', 'public', 'users'),
         ('system-test', 'public', 'organization_memberships'),
         ('system-test', 'public', 'repository_memberships'),
         ('system-test', 'public', 'file_versions'),
         ('system-test', 'public', 'public_keys'),
         ('system-test', 'public', 'loc_id_bases');
SELECT emaj.emaj_create_group('system-test');
SELECT emaj.emaj_start_group('system-test');
