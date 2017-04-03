# System-tests for Ontohub

## Installation

To run the tests you need to install the emaj database extension.
Follow the instructions on [emaj website](http://emaj.readthedocs.io/en/latest/download.html). There may be some problems so the step by step installation, which worked for us, is listed below.

* Download the package from [PGXN](https://pgxn.org/dist/e-maj/) (see instructions in emaj docu) and unzip it
* Copy latest emaj version sql file (e.g. `emaj--2.0.1.sql` in unzipped folder) and `emaj.control` file in the `SHAREDIR` directory (check with `pg_config --sharedir`). On e.g. Arch Linux it's `/usr/share/postgresql`, maybe you have to copy the files to `/usr/share/postgresql/extension`. You can leave the `emaj--2.0.1.sql` file where it is and just adjust the directory parameter in the `emaj.control` file to reflect the location of it. Skip if you copied both files.
* Rest of the steps will be executed when you run `cucumber` (see `features/support/emaj.sql`)
* First execution could take a while (because there is a `git clone` etc.), everything is fine if all the tests are green in the end
