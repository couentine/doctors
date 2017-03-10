## Setting up Tsung ##

1. Install the required Erlang dependencies.

        Ubuntu: $ sudo apt-get install erlang gnuplot libtemplate-perl

        Mac: $ brew install erlang gnuplot libtemplate-perl

2. Once the dependencies are installed, install tsung itself directly from the latest release like so:

        $ wget http://tsung.erlang-projects.org/dist/tsung-1.5.1.tar.gz
        $ tar zxvf tsung-.5.1.tar.gz
        $ cd tsung-1.5.1
        $ ./configure && make && make install

3. Tests are configured using an XML file, which is then executed to produce a series of output files. Launch the test, specifying the XML file, like so:

        $ tsung -f sign_in_script.xml start

4. Log files are saved in ~/.tsung/log/. A new subdirectory is created for each test using the current date and time as name, e.g. ~/.tsung/log/20141107-1047

5. Go to particular directory and generate the statistics report as follows.

        $ cd /root/.tsung/log/20141107-1047
        $ /usr/lib/tsung/bin/tsung_stats.pl

5. Open report.html to see the Stats Report and Graph Report.
