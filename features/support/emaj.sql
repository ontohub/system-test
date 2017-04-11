CREATE EXTENSION dblink;
CREATE EXTENSION emaj;
INSERT INTO emaj.emaj_group_def (grpdef_group, grpdef_schema, grpdef_tblseq)
  VALUES ('system-test', 'public', 'organizational_units'),
         ('system-test', 'public', 'organizations'),
         ('system-test', 'public', 'repositories'),
         ('system-test', 'public', 'users'),
         ('system-test', 'public', 'organizations_members'),
         ('system-test', 'public', 'file_versions'),
         ('system-test', 'public', 'loc_id_bases');
SELECT emaj.emaj_create_group('system-test');
SELECT emaj.emaj_start_group('system-test');
