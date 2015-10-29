ziptime -- zip timestamp tool

usage: ziptime file.zip

  file.zip is an existing Zip archive to rewrite


This tools replaces the timestamps in the zip headers with a static time
(Jan 1 2008). The extra fields are not changed, so you'll need to use the
-X option to zip so that it doesn't create the 'universal time' extra.
