#!/usr/bin/env perl
use inc::Module::Install;

name 'Moreland-Scraper';
all_from 'script/moreland_scrape.pl';

requires 'WWW::Mechanize';
requires 'HTML::TreeBuilder::XPath';
requires 'XML::Simple';

install_script glob('script/*.pl');

auto_install;

WriteAll;
