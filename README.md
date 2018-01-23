# System-tests for Ontohub

## Installation

To run the tests you need to install the emaj database extension. This extensions enables rollbacks on the database without using database-level transactions.
If the following instructions don't work, follow the instructions on the [emaj Github Readme](https://github.com/beaud76/emaj) or the [emaj documentation](http://emaj.readthedocs.io/en/latest/install.html).

Go to the [extension download page](https://pgxn.org/dist/e-maj/) and find the version number of the latest release of E-Maj.
Run the following commands in your bash or zsh (and adjust the version in the first line):

```bash
# Adjust the version
VERSION="2.2.1"

SHAREDIR="$(pg_config --sharedir)"
curl -L http://api.pgxn.org/dist/e-maj/${VERSION}/e-maj-${VERSION}.zip > $TMPDIR/e-maj-${VERSION}.zip
tar xf e-maj-${VERSION}.zip
cd e-maj-${VERSION}
cp sql/emaj--${VERSION}.sql emaj.control $SHAREDIR/extension
```

Otherwise, you can do this manually with these steps:

* Download the package from [PGXN](https://pgxn.org/dist/e-maj/) and unzip it
* Copy latest emaj version sql file (e.g. `sql/emaj--2.2.1.sql` in unzipped folder) and `emaj.control` file in the `SHAREDIR` directory (check with `pg_config --sharedir`). On e.g. Arch Linux it's `/usr/share/postgresql`, maybe you have to copy the files to `/usr/share/postgresql/extension`. Alternatively, you can leave the `emaj--2.2.1.sql` file where it is and just adjust the directory parameter in the `emaj.control` file to reflect the location of it.
* The rest of the steps will be executed when you run `cucumber` (see `features/support/emaj.sql`)

## Running the tests
* Run `cucumber` to start the test suite. This also sets up the ontohub-specifics for E-Maj.
* The first execution could take a while, because all the sub-projects' repositories need to be cloned. Everything is fine if all the tests are green in the end.
* If you want the tests to run on specific commits you can run `ONTOHUB_BACKEND_VERSION='12345678abcdefg' ONTOHUB_FRONTED_VERSION='12345678abcdefg' HETS_RABBITMQ_WRAPPER_VERSION='12345678abcdefg' cucumber`. If you want e.g. just the backend in a specific revision, only use `ONTOHUB_BACKEND_VERSION`. Remember that the tests may fail depending on the commits that you check out.
