#!/usr/bin/perl


#binmode STDIN, ':encoding(cp932)';
#binmode STDOUT, ':encoding(cp932)';
#binmode STDERR, ':encoding(cp932)';
#use warnings;
use strict;
use utf8;
use URI::Escape;
use HTML::Entities;
use LWP::UserAgent;
use Getopt::Long;
use FindBin;


$|=1;


my %opts = ();
GetOptions (\%opts, 'search','xmlcorr','abscorr','delimit','fldfmt=s','order=s','browse');
#Options
## --search, -s: keyword search mode
## --xmlcorr, -x: PubMed XML correction mode
## --abscorr, -a: PubMed abstract text correction mode
## --delimiter, -d: delimiter mode
## --fldfmt, -f: field format option; takes an argument
## --order, -o: ordering option; takes an argument
## --interact, -i: interactive mode
## --browse, -b: to browse a reference file formatted by "-f all" or "-f DB", by which all paper information is output as a tab-delimited form





my @refkeylist;
my $refkeyindex;
my $sortindex;
my $orgrefkey;
my $refkey;
my $url;
my $user_agent = 'Mozilla/5.0';
my $ua = LWP::UserAgent->new;
$ua->agent($user_agent);

my $mstext;
my $inputref;
my $pmabstract;
my $pmabstract0;
my @pmabslist;
my @paperinfo;
my $indexkey ='';
my $pindex='';
my $journal='';
my $fulljournal='';
my $year='';
my $date='';
my $voliss;
my $volume='';
my $issue='';
my $pages='';
my $title='';
my $author='';
my $fullauthor='';
my @authorlist;
my @fullauthlist;
my $firstauthor;
my @attributelist;
my $attribute='';
my $institute='';
my $abstract='';
my $doi='';
my $pmcid='';
my $pmid='';
my @abstxtlist;
my @allinfo;
my @finalallinfo;
my %fmtout_sval;
my %finalauthyr;
my @concinfolist;
my %auth_year;
my %auth_year2;
my $fmtoutput;
my $fmtabs;
my $papernum;
my @specieslist;
my @pmjalltitle;
my @pmjftitle;
my @pmjtabbr1;
my @pmjtabbr2;
my @allspecies;

#To set a customized format
my $myownfmt;

#List of preset formats
my @fmtlist = ('DB=NOHTML','all=NOHTML', 'default=NOHTML','smod=NOHTML','hokudai=NOHTML','lcp=NOHTML','febs=NOHTML','npg=NOHTML','abstracts=NOHTML','raw=NOHTML','unchanged=NOHTML','custom=NOHTML','own=NOHTML');



#Subroutines
##Reset all information about a paper
sub valresetting {
	$indexkey ='';
	$pindex='';
	$journal='';
	$fulljournal = '';
	$year='';
	$date='';
	$voliss='';
	$volume='';
	$issue='';
	$pages='';
	$title='';
	$author='';
	$fullauthor='';
	@authorlist=();
	@fullauthlist=();
	$firstauthor='';
	@attributelist=();
	$attribute='';
	$institute='';
	$abstract='';
	$doi='';
	$pmcid='';
	$pmid='';
	$pmabstract='';
	$pmabstract0='';
	@pmabslist=();
	@paperinfo=();
	@concinfolist =();
	@allinfo=();
	@abstxtlist =();
	$fmtoutput='';
	$papernum='';
}

##Loading a list of journals available in PubMed
sub pmjlisting {
	if (open (JLF, "< jlist.txt")) {
		open (JLF, "< jlist.txt");
		while (my $line = <JLF>) {
			$line =~ s/\r\n$|\n$|\r$//g;
			if ($line =~ /^JournalTitle: (.+)/) {
				push (@pmjftitle, $1);
			} elsif ($line =~ /^MedAbbr: (.+)/) {
				push (@pmjtabbr1, $1);
			} elsif ($line =~ /^IsoAbbr: (.+)/) {
				push (@pmjtabbr2, $1);
			}
		}
		close (JLF);
		@pmjalltitle = (@pmjftitle, @pmjtabbr1, @pmjtabbr2);
		@pmjalltitle = sort {length($b) <=> length($a)} @pmjalltitle;
		for my $i (@pmjalltitle) {
			$i =~ s/\W/./g;
			$i =~ s/\.\././g;
		}
		print STDERR "Journal list was loaded\r\n\r\n";
	}
}

##Loading species names
sub spcnlisting {
	if (open (SNF, "< slist.txt")) {
		open (SNF, "< slist.txt");
		@allspecies = <SNF>;
		close (SNF);
		for my $i (@allspecies) {
			$i =~ s/[\r\n]//g;
			$i =~ s/^ +| +$//g;
		}
		sort {length($b) <=> length($a)} @allspecies;
		print STDERR "Species list was loaded\r\n\r\n";
	}
}

##Arranging fields
sub formatting {
	if (!$opts{xmlcorr} && !$opts{abscorr} && !$opts{searching} && !$mstext) {
		$author =~ s/^ +| +$//g;
		$author =~ s/([A-Z][a-z\'\-\?][A-Za-z\'\?\-]*( [A-Z][a-z\'\-\?][A-Za-z\'\?\-]*){0,})\,/$1/g;
		$author =~ s/ and | \& /, /g;
		$author =~ s/([A-Z])\.$/$1/g;
		$author =~ s/([A-Z])\.\,/$1,/g;
		$author =~ s/([A-Z])[ \.]+([A-Z])/$1$2/g;
		$author =~ s/([A-Z])[ \.]+([A-Z])/$1$2/g;
		$author =~ s/([A-Z])[ \.]+([A-Z])/$1$2/g;
		@authorlist = split (/[\,\;]/, $author);
		$firstauthor = @authorlist[0];
	}
	for my $g (@authorlist) {
		if ($g =~ /([A-Z]+) ([A-Z][a-z\'\-\?][A-Za-z\'\?\-]*( [A-Z][a-z\'\-\?][A-Za-z\'\?\-]*){0,})/) {
			$g =~ s/$&/$2 $1/;
		}
	}
	if ($author =~ /^[A-Z]+ /) {
		$author = join (', ',@authorlist);
	}
	if (!$opts{fldfmt} || $opts{fldfmt} =~ /smod|default|abstract/i) {
		$fmtoutput = $journal.'. '.$year.'. '.$volume.'('.$issue.'): '.$pages."\.\r\n".$title."\r\n".$author.".\r\nDOI: ".'https://dx.doi.org/'.$doi."\r\nPMID: ".'http://www.ncbi.nlm.nih.gov/pubmed/'.$pmid;
		$fmtoutput =~ s/\(\)//g;
		$fmtoutput =~ s/\: *?\././g;
		if ($opts{fldfmt} =~ /abstract/i) {
			$fmtoutput = "\r\n".$fmtoutput."\r\n\r\n".$abstract."\r\n";
		}
	} elsif ($opts{fldfmt} =~ /lcp|hokudai/i) {
		$fmtoutput = '<li>'.$author.'. '.$title.'. <i>'.$journal.'</i>. '.$year.'. <b>'.$volume.'</b>('.$issue.'): '.$pages.'. DOI: <a href = "https://dx.doi.org/'.$doi.'>'.$doi.'</a>. PMID: <a href = "http://www.ncbi.nlm.nih.gov/pubmed/'.$pmid.'>'.$pmid.'</a>.</li>';
		$fmtoutput =~ s/\(\)|[\r\n]//g;
		$fmtoutput =~ s/\. *\././g;
		$fmtoutput =~ s/(Masuda K)|(Fujino K)|(Shimura H)|(Tsugama D)/<u>$&<\/u>/g;
	} elsif ($opts{fldfmt} =~ /febs/i) {
		@authorlist = split (/[\,\;]/,$author);
		if ($#authorlist >= 1) {
			$author = join (', ',@authorlist[0..($#authorlist-1)]);
			$author = $author.' & '.$authorlist[$#authorlist];
		}
		$author =~ s/\, \& / & /;
		$author =~ s/  / /g;
		$author =~ s/  / /g;
		$author =~ s/\& et al/et al/g;
		$fmtoutput = $author.' ('.$year.') '.$title.'. <i>'.$journal.'</i> '.$volume.', '.$pages.'.';
		$fmtoutput =~ s/et al /et al. /g;
	} elsif ($opts{fldfmt} =~ /npg/i) {
		$author =~ s/[A-Z][a-z\'\?][A-Za-z\'\?\-]*( [A-Z][a-z\'\?][A-Za-z\'\?\-]*){0,}/$&,/g;
		$author =~ s/([A-Z])$/$1./;
		$author =~ s/([A-Z])\,/$1.,/g;
		$author =~ s/([A-Z])([A-Z])/$1. $2/g;
		$author =~ s/([A-Z])([A-Z])/$1. $2/g;
		$author =~ s/([A-Z])([A-Z])/$1. $2/g;
		$author =~ s/\. *\././g;
		$author =~ s/\. *\././g;
		$author =~ s/\, ([A-Z][a-z\'\-\?][A-Za-z\'\?\-]*( [A-Z][a-z\'\-\?][A-Za-z\'\?\-]*){0,}\, ([A-Z]\. ){0,}[A-Z]+\.)$/ & $1/g;
		$fmtoutput = $author.' '.$title.'. <i>'.$journal.'</i> <b>'.$volume.'</b>, '.$pages.' ('.$year.').';
		$fmtoutput =~ s/et al /et al. /g;
	} elsif (!$opts{fldfmt} || $opts{fldfmt} =~ /raw|unchange/i) {
		$fmtoutput = $orgrefkey;
	} elsif ($opts{fldfmt} =~ /custom|own/i) {
		$fmtoutput = $myownfmt;
	} elsif ($opts{fldfmt} =~ /all/i | $opts{fldfmt} =~ /DB/) {
		$attribute = join ('; ',@attributelist);
		$attribute =~ s/^ *?\; *?|\; *?$//g;
		$attribute =~ s/^ +| +$//g;
		$fmtoutput = $author."\t".$title."\t".$year."\t".$journal."\t".$volume."\t".$issue."\t".$pages."\t".'https://www.ncbi.nlm.nih.gov/pubmed/'.$pmid."\t".'https://www.ncbi.nlm.nih.gov/pmc/articles/'.$pmcid."\t".'https://dx.doi.org/'.$doi."\t".$attribute.'|Author Information: '.$institute."\t".$abstract;
		$fmtoutput =~ s/et al /et al. /g;
	}
	if ($opts{fldfmt} =~ /\=NO*H/) {
		$fmtoutput =~ s/\<\/{0,1}[liubar].*?\>//sig;
	}
	if ($opts{order} =~ /num|index/i) {
		$fmtout_sval{$fmtoutput} = $indexkey;
	} elsif ($opts{order} =~ /name|author/i) {
		$fmtout_sval{$fmtoutput} = $firstauthor.','.$year.','.$pmid;
	} elsif ($mstext) {
		$fmtout_sval{$fmtoutput} = $firstauthor.','.$year;
	} elsif ($opts{order} =~ /year/i) {
		$fmtout_sval{$fmtoutput} = $year.','.$firstauthor.','.$pmid;
	} elsif ($opts{order} =~ /pm/i) {
		$fmtout_sval{$fmtoutput} = $pmid;
	} elsif ($opts{order} =~ /title/i) {
		$fmtout_sval{$fmtoutput} = $title;
	}
}


##Extracting information about a paper from PubMed XML-formatted information
sub pmxmlcorrection {
	$pmabstract =~ s/^ +| +$//g;
	$pmabstract =~ s/^.*?\Q<PubmedArticle>\E//s;
	@pmabslist = split (/\Q<PubmedArticle>\E/,$pmabstract);
	my %instituteinfo;
	for my $i (@pmabslist) {
		$pindex = '';
		$journal = '';
		$fulljournal = '';
		$year = '';
		$date = '';
		$voliss = '';
		$volume = '';
		$issue = '';
		$pages = '';
		$doi = '';
		$pmcid = '';
		$pmid = '';
		$title = '';
		$author = '';
		$institute = '';
		@attributelist = '';
		@authorlist=();
		@fullauthlist=();
		$attribute = '';
		$abstract = '';
		if ($i =~ /\<Journal\>.*?\<Volume\>(.+?)\<\/Volume\>.*?\<\/Journal\>/s) {
			$volume=$1;
		} elsif ($i =~ /\<PublicationStatus\>aheadofprint\<\/PublicationStatus\>/) {
			$volume='ahead of print';
		}
		if ($i =~ /\<Journal\>.*?\<Issue\>(.+?)\<\/Issue\>.*?\<\/Journal\>/s) {
			$issue=$1;
		}
		if ($i =~ /\<Journal\>.*?\<PubDate\>.*?\<Year\>(.+?)\<\/Year\>.*?\<\/PubDate\>/s) {
			$year=$1;
		} elsif ($i =~ /\<Journal\>.*?\<PubDate\>.*?\([12]\d{3}).*?\<\/PubDate\>/s) {
			$year=$1;
		}
		if ($i =~ /\<Journal\>.*?\<PubDate\>.*?\<Month\>(.+?)\<\/Month\>.*?\<\/PubDate\>/s) {
			$date=$1;
		}
		if ($i =~ /\<Journal\>.*?\<PubDate\>.*?\<Day\>(.+?)\<\/Day\>.*?\<\/PubDate\>/s) {
			$date=$date.' '.$1;
		}
		if ($i =~ /\<Journal\>.*?\<Title\>(.+?)\<\/Title\>.*?\<\/Journal\>/s) {
			$fulljournal=$1;
		}
		if ($i =~ /\<Journal\>.*?\<ISOAbbreviation\>(.+?)\<\/ISOAbbreviation\>.*?\<\/Journal\>/s) {
			$journal=$1;
			$journal =~ s/\.$//g;
		}
		if ($i =~ /\<ArticleTitle\>(.+?)\<\/ArticleTitle\>/s) {
			$title=$1;
		}
		if ($i =~ /\<Pagination\>.*?\<MedlinePgn\>(.+?)\<\/MedlinePgn\>.*?\<\/Pagination>/s) {
			$pages = $1;
		}
		if ($pages =~ /\-/){
			my ($startpage, $endpage) = split(/\-/,$pages);
			if ($startpage > $endpage){
				my $epdigit = 10**length($endpage);
				my $truncated = int($startpage / $epdigit);
				my $modendpage = $truncated.$endpage;
				$pages = $startpage.'-'.$modendpage;
			}
		}
		if ($i =~ /\<AbstractText>(.+?)\<\/AbstractText\>/s) {
			$abstract=$1;
		} else {
			for (1..10) {
				if ($i =~ /\<AbstractText Label\=\"(.+?)\".*?\>(.+?)\<\/AbstractText\>/s) {
					$abstract=$abstract.' '.$1.': '.$2;
					$i =~ s/\Q$&\E//;
				}
			}
		}
		if ($i =~ /\<\QAuthorList CompleteYN="Y"\E\>(.+?)\<\/AuthorList\>/s) {
			my $authfield=$1;
			my @tmpauthlist = split (/\Q<Author ValidYN="Y">\E/,$authfield);
			my $lastname;
			my $forename;
			my $initials;
			for my $j (@tmpauthlist) {
				$lastname='';
				$forename='';
				$initials='';
				if ($j =~ /\<LastName\>(.+?)\<\/LastName\>/s) {
					$lastname=$1;
				}
				if ($j =~ /\<ForeName\>(.+?)\<\/ForeName\>/s) {
					$forename=$1;
				}
				if ($j =~ /\<Initials\>(.+?)\<\/Initials\>/s) {
					$initials=$1;
				}
				if ($lastname =~ /\w+/) {
					push (@fullauthlist, $forename.' '.$lastname);
					push (@authorlist, $lastname.' '.$initials);
				}
				if ($i =~ /\Q$lastname\E.*?\<AffiliationInfo\>.*?\<Affiliation\>(.+?)\<\/Affiliation\>/s) {
					$instituteinfo{$lastname} = $1;
				}
			}
		}
		$fullauthor = join (', ',@fullauthlist);
		$author = join (', ',@authorlist);
		$firstauthor = $authorlist[0];
		for my $j (0..$#authorlist) {
			for my $k (keys %instituteinfo) {
				my $curauthnum = $j+1;
				if ($authorlist[$j] =~ /\Q$k\E/) {
					$institute = $institute.'('.$curauthnum.')'.$instituteinfo{$k};
				}
			}
		}
		$institute =~ s/^ +| +$//g;
		$institute =~ s/(\S)\(/$1 (/g;
		if($i =~ /\<ArticleIdList\>.*\<\QArticleId IdType="pubmed"\E\>(.+?)\<\/ArticleId\>/s) {
			$pmid=$1;
		}
		if($i =~ /\<ArticleIdList\>.*\<\QArticleId IdType="doi"\E\>(.+?)\<\/ArticleId\>/s) {
			$doi=$1;
		}
		if($i =~ /\<ArticleIdList\>.*\<\QArticleId IdType="pmc"\E\>(.+?)\<\/ArticleId\>/s) {
			$pmcid=$1;
		}
		while ($i =~ /\Q<CommentsCorrections RefType="CommentIn">\E/) {
			if($i =~ /\Q<CommentsCorrections RefType="CommentIn">\E.*?\<RefSource\>(.+?)\<\/RefSource\>/s) {
				push (@attributelist, 'Comment in '.$1);
				$i =~ s/\Q$&\E//;
			} else {
				$i =~ s/\Q<CommentsCorrections RefType="CommentIn">\E//;
			}
		}
		while ($i =~ /\Q<CommentsCorrections RefType="ErratumIn">\E/) {
			if($i =~ /\Q<CommentsCorrections RefType="ErratumIn">\E.*?\<RefSource\>(.+?)\<\/RefSource\>/s) {
				push (@attributelist, 'Erratum in '.$1);
				$i =~ s/\Q$&\E//;
			} else {
				$i =~ s/\Q<CommentsCorrections RefType="ErratumIn">\E//;
			}
		}
		while ($i =~ /\<PublicationType[^L].*?\>(.+?)<\/PublicationType\>/s) {
			push (@attributelist, $1);
			$i =~ s/\Q$&\E//;
		}
		$date =~ s/^\s+?|\s+$//g;
		$author =~ s/[\r\n]+/ /g;
		$author =~ s/\(.*?\)|\.$//g;
		$title =~ s/[\r\n]+/ /g;
		$title =~ s/\.\s*?$//g;
		$abstract =~ s/[\r\n]+/ /g;
		$abstract =~ s/^ +?| +$//g;
		$doi =~ s/^\s+?|\s+$//g;
		$pmcid =~ s/^\s+?|\s+$//g;
		$pmid =~ s/^\s+?|\s+$//g;
		@authorlist = split(/\, /,$author);
		$firstauthor = $authorlist[0];
		if (@attributelist) {
			$attribute = join ('; ',@attributelist);
			$attribute =~ s/^ *?\; *?|\; *?$//g;
			$attribute =~ s/^ +| +$//g;
			$attribute =~ s/[\r\n]+/ /g;
			$fmtoutput = $journal.'. '.$year.'. '.$volume.'('.$issue.'): '.$pages."\.\r\n".$title."\r\n".$author."\r\nDOI: ".'https://dx.doi.org/'.$doi."\r\nPMID: ".'http://www.ncbi.nlm.nih.gov/pubmed/'.$pmid."\r\n".$attribute;
		} else {
			$fmtoutput = $journal.'. '.$year.'. '.$volume.'('.$issue.'): '.$pages."\.\r\n".$title."\r\n".$author."\r\nDOI: ".'https://dx.doi.org/'.$doi."\r\nPMID: ".'http://www.ncbi.nlm.nih.gov/pubmed/'.$pmid;
		}
		$fmtoutput =~ s/\(\)//g;
		push (@concinfolist,$fmtoutput);
		$fmtabs = $fmtoutput."\r\n\r\n".$abstract;
		push (@abstxtlist,$fmtabs);
		formatting();
		if ($journal ne '' || $#pmabslist > 0) {
			push (@allinfo,$fmtoutput);
		} elsif ($journal eq '' && $#pmabslist == 0) {
			print STDERR "$refkey (line $refkeyindex) has no hit\r\n\r\n";
			print STDERR "Adding '*' to the keyword and proceeding\r\n\r\n";
			$fmtoutput ='*'.$orgrefkey;
			push (@finalallinfo,$fmtoutput);
		}
	}
}


##Extracting information about a paper from PubMed-abstract (text) information
sub pmabscorrection {
	@pmabslist = split (/\r\n\r\n\r\n+\d+\. |\n\n\n+\d+\. |\r\r\r+\d+\. /,$pmabstract);
	$pmabslist[0] =~ s/^\d+?\. //;
	for my $i (0..$#pmabslist) {
		$pindex = '';
		$journal = '';
		$fulljournal = '';
		$year = '';
		$date = '';
		$voliss = '';
		$volume = '';
		$issue = '';
		$pages = '';
		$doi = '';
		$pmcid = '';
		$pmid = '';
		$title = '';
		$author = '';
		$institute = '';
		@attributelist = '';
		$attribute = '';
		$abstract = '';
		$pmabslist[$i] =~ s/^\d+?\. //;
		@paperinfo = split(/\r\n\r\n|\n\n|\r\r/,$pmabslist[$i]);
		$paperinfo[0] =~ s/[\r\n]//g;
		if($paperinfo[0] =~ /^([a-zA-Z\& \(\)]+?)\. ([a-zA-Z\d \-\&]*?)\;{0,1}([a-zA-Z0-9 \-\(\)]*?)\:{0,1}([a-zA-Z0-9\-]*?)\./){
			$pindex=$i+1;
			$journal=$1;
			$year=$2;
			$voliss=$3;
			$pages=$4;
		}
		if ($year =~ /([12]\d{3})\s*([a-zA-Z\d \-\&]*)/) {
			$year = $1;
			$date = $2;
		} elsif  ($year =~ /([a-zA-Z\d \-\&]*)\s*(\d{4})/) {
			$year = $2;
			$date = $1;
		}
		if ($voliss =~ /([a-zA-Z0-9]+)\(([a-zA-Z0-9]+)\)/){
			$volume = $1;
			$issue = $2;
		} else {
			$volume = $voliss;
			$issue='';
		}
		if ($pages =~ /\-/){
			my ($startpage, $endpage) = split(/\-/,$pages);
			if ($startpage > $endpage){
				my $epdigit = 10**length($endpage);
				my $truncated = int($startpage / $epdigit);
				my $modendpage = $truncated.$endpage;
				$pages = $startpage.'-'.$modendpage;
			}
		}
		$title = $paperinfo[1];
		if ($paperinfo[2] !~ /^\[/) {
			$author = $paperinfo[2];
		} else {
			push (@attributelist,$paperinfo[2]);
			$author = $paperinfo[3];
		}
		for my $j (2..4) {
			if ($paperinfo[$j] =~ /Author information/) {
				$institute = $paperinfo[$j];
			}
		}
		if ($institute eq '' && $paperinfo[3] !~ /Erratum|Comment in/) {
			$abstract = $paperinfo[3];
		} elsif ($paperinfo[4] !~ /Erratum|Comment in/){
			$abstract=$paperinfo[4];
		} elsif ($paperinfo[4] =~ /Erratum|Comment in/) {
			$abstract=$paperinfo[5];
		}
		for my $j (3..$#paperinfo) {
			if($paperinfo[$j] =~ /Erratum|Comment in/){
				push (@attributelist, $paperinfo[$j]);
			}
			if($paperinfo[$j] =~ /^DOI\: (\S+)[ \[\r\n]/){
				$doi=$1;
			}
			if($paperinfo[$j] =~ /PMCID\: (\S+)[ \[\r\n]/){
				$pmcid=$1;
			}
			if($paperinfo[$j] =~ /PMID\: (\S+)[ \[\r\n]/){
				$pmid=$1;
			}
		}
		$date =~ s/^\s+?|\s+$//g;
		$author =~ s/[\r\n]/ /g;
		$author =~ s/\(.*?\)|\.$//g;
		$title =~ s/[\r\n]/ /g;
		$title =~ s/\.\s*?$//g;
		$abstract =~ s/[\r\n]/ /g;
		$doi =~ s/^\s+?|\s+$//g;
		$pmcid =~ s/^\s+?|\s+$//g;
		$pmid =~ s/^\s+?|\s+$//g;
		@authorlist = split(/\, /,$author);
		$firstauthor = $authorlist[0];
		if (@attributelist) {
			$attribute = join ('; ',@attributelist);
			$attribute =~ s/^ *?\; *?|; *?$//g;
			$attribute =~ s/^ +| +$//g;
			$fmtoutput = $journal.'. '.$year.'. '.$volume.'('.$issue.'): '.$pages."\.\r\n".$title."\r\n".$author."\r\nDOI: ".'https://dx.doi.org/'.$doi."\r\nPMID: ".'http://www.ncbi.nlm.nih.gov/pubmed/'.$pmid."\r\n".$attribute;
		} else {
			$fmtoutput = $journal.'. '.$year.'. '.$volume.'('.$issue.'): '.$pages."\.\r\n".$title."\r\n".$author."\r\nDOI: ".'https://dx.doi.org/'.$doi."\r\nPMID: ".'http://www.ncbi.nlm.nih.gov/pubmed/'.$pmid;
		}
		$fmtoutput =~ s/\(\)//g;
		push (@concinfolist,$fmtoutput);
		$fmtabs = $fmtoutput."\r\n\r\n".$abstract;
		push (@abstxtlist,$fmtabs);
		formatting();
		if ($journal ne '' || $#pmabslist > 0) {
			push (@allinfo,$fmtoutput);
		} elsif ($journal eq '' && $#pmabslist == 0) {
			print STDERR "$refkey (line $refkeyindex) has no hit\r\n\r\n";
			print STDERR "Adding '*' to the keyword and proceeding\r\n\r\n";
			$fmtoutput ='*'.$orgrefkey;
			push (@finalallinfo,$fmtoutput);
		}
	}
}


sub pmsearching {
	$url = 'https://www.ncbi.nlm.nih.gov/pubmed/?term='.$refkey.'&report=xml&format=text';
	my $response = $ua->get($url);
	if ($response->is_success) {
		$pmabstract = $response->content;
		$pmabstract = decode_entities($pmabstract);
		pmxmlcorrection();
		for my $i (0..$#concinfolist) {
			if ($journal ne '' || $#concinfolist > 0) {
				my $paperindex = $i+1;
				print STDERR "$paperindex. $concinfolist[$i]\r\n\r\n";
			}
		}
		if ($#concinfolist == 0 && $journal ne '') {
			print STDERR "The above unique paper was found for $refkey (line $refkeyindex)\r\n\r\n";
			print STDERR "Adding it to the list for final output and proceeding\r\n\r\n";
			push (@finalallinfo,$fmtoutput);
		} elsif ($#concinfolist > 0) {
			$papernum = $#concinfolist+1;
			print STDERR "The above $papernum papers were found for $refkey (line $refkeyindex)\r\n";
		}
		if ($#concinfolist == 19) {
			print STDERR "Probably more papers are present\r\n";
			print STDERR "Get them?\r\n\r\n";
			print STDERR " * 'Y' or 'y': gets up to 200 papers\r\n";
			print STDERR " * Number: gets papers up to this number\r\n";
			print STDERR "     1000: gets up to 1000 papers, for example\r\n";
			print STDERR " * 'S' or 's': proceeds without using any of them\r\n";
			print STDERR " * 'Q' or 'q': ends program\r\n";
			print STDERR " * Any other key: proceeds with the 20 papers obtained\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'Q' || $answer eq 'q') {
				print STDERR "\r\nEnding program\r\n\r\n";
				exit;
			} elsif ($answer eq 'S' || $answer eq 's') {
				print STDERR "\r\nSkipping\r\n\r\n";
				next;
			}
			my $retnum;
			if ($answer eq 'Y' || $answer eq 'y' || ($answer =~ /^\d+$/ && $& > 0)) {
				valresetting();
				if ($answer eq 'Y' || $answer eq 'y') {
					$retnum = 200;
				} elsif ($answer =~ /^\d+$/ && $& > 0) {
					$retnum = $answer;
				}
				print STDERR "\r\nCollecting information\r\n\r\n";
				$url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term='.$refkey.'&retmax='.$retnum;
				my $response = $ua->get($url);
				my $pmidlist0;
				if ($response->is_success) {
					$pmidlist0 = $response->content;
					$pmidlist0 =~ s/\<\/Id\>|\<Id\>| //g;
					$pmidlist0 =~ s/[\r\n]/+/g;
					$pmidlist0 =~ s/.*\<IdList\>//sg;
					$pmidlist0 =~ s/\<\/IdList\>.*//sg;
					$pmidlist0 =~ s/^\++?|\++?$//;
					my @pmidlist = split (/\+/,$pmidlist0);
					my $pmidlistnum = $#pmidlist + 1;
					for my $i (0..$#pmidlist) {
						if ($i % 10 == 0) {
							print STDERR "$i / $pmidlistnum papers were processed\r\n";
						}
						$url = 'https://www.ncbi.nlm.nih.gov/pubmed/?term='.$pmidlist[$i].'&report=xml&format=text';
						$response = $ua->get($url);
						if ($response->is_success) {
							$pmabstract = $response->content;
							$pmabstract = decode_entities($pmabstract);
							pmxmlcorrection();
						}
					}
					print STDERR "$pmidlistnum papers were processed\r\n\r\n";
					for my $i (0..$#concinfolist) {
						my $paperindex = $i+1;
						print STDERR "$paperindex. $concinfolist[$i]\r\n\r\n";
					}
				} else {
					print STDERR "Unexpected error happened\r\n\r\n";
					print STDERR "Ending program\r\n";
					exit;
				}
				$papernum = $#concinfolist+1;
				if ($papernum > 1) {
					print STDERR "The above $papernum papers were found for $refkey (line $refkeyindex)\r\n\r\n";
				} else {
					print STDERR "The above $papernum paper was found\r\n";
					print STDERR "\r\nUse it for output?\r\n";
					print STDERR "* 'Y' or 'y': yes\r\n";
					print STDERR "* 'Q' or 'q': ends program\r\n";
					print STDERR "* Any other key: no and proceeds\r\n\r\n";
					my $subanswer = <STDIN>;
					$subanswer =~ s/[\r\n]//g;
					if ($subanswer eq 'Q' || $subanswer eq 'q') {
						print STDERR "\r\nEnding program\r\n";
						exit;
					} elsif ($subanswer eq 'Y' || $subanswer eq 'y') {
						push (@finalallinfo,@allinfo[0]);
					}
					print STDERR "\r\nProceeding\r\n\r\n";
				}
			} else {
				print STDERR "\r\nProceeding with the 20 papers obtained\r\n\r\n";
			}
		}
		if ($#concinfolist > 0) {
			print STDERR "What to do?\r\n";
			print STDERR " * 'F' or 'f': formats information on all ($papernum) of them\r\n";
			print STDERR " * Delimited numbers: format information on correponding papers\r\n";
			print STDERR "     2 3 5-7: format information on the papers 2, 3, 5, 6, 7 for example\r\n";
			print STDERR " * 'A' or 'a': shows abstracts of all of them\r\n";
			print STDERR " * Delimited numbers with 'a': show abstracts of corresponding papers\r\n";
			print STDERR "     1-3a 7a: show abstracts of the papers 1, 2, 3 and 7, for example\r\n";
			print STDERR " * 'Q' or 'q': ends program\r\n";
			print STDERR " * Any other key: proceeds without using any of them\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'q' || $answer eq 'Q') {
				print STDERR "\r\nEnding program\r\n";
				exit;
			} elsif ($answer eq 'F' || $answer eq 'f') {
				print STDERR "\r\nAdding them to the list for final output and proceeding\r\n\r\n";
				for my $i (@allinfo) {
					push (@finalallinfo,$i);
				}
			} elsif ($answer =~ /\d+a/i) {
				$answer =~ s/[aA]//g;
				my @abstoshow = split (/[\s\,\;\:]/,$answer);
				for my $i (@abstoshow) {
					$i =~ s/[ aA]//g;
					if ($i =~ /(\d+?)\D+?(\d+?)/) {
						my @seqnum = ($1..$2);
						push (@abstoshow,@seqnum);
						$i = 0;
						@abstoshow = sort {$a <=> $b} @abstoshow;
					}
				}
				print STDERR "Following are abstracts \~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\r\n\r\n\r\n";
				for my $i (@abstoshow) {
					if ($i > 0) {
						print STDERR "$i. $abstxtlist[$i-1]\r\n\r\n\r\n";
					}
				}
				print STDERR "\r\nWhat to do?\r\n";
				print STDERR " * 'F' or 'f': formats information on all of them\r\n";
				print STDERR " * Delimited numbers: format information on correponding papers\r\n";
				print STDERR "     2 3 5-7: format information on the papers 2, 3, 5, 6, 7 for example\r\n";
				print STDERR " * Delimited numbers with 'a': show abstracts one by one and make decisions\r\n";
				print STDERR "     1-3a 7a: show abstracts of the papers 1, 2, 3 and 7, for example\r\n";
				print STDERR " * 'Q' or 'q': ends program\r\n";
				print STDERR " * Any other key: proceeds without using any of them\r\n\r\n";
				my $subanswer = <STDIN>;
				$subanswer =~ s/[\r\n]//g;
				if ($subanswer eq 'Q' || $subanswer eq 'q') {
					print STDERR "Ending program\r\n";
					exit;
				} elsif ($subanswer eq 'F' || $subanswer eq 'f') {
					print STDERR "Adding them to the list for final output and proceeding\r\n\r\n";
					for my $i (@allinfo) {
						push (@finalallinfo,$i);
					}
				} elsif ($subanswer =~ /\d+a/i) {
					my @subabstoshow = split (/[\s\,\;\:]/,$subanswer);
					for my $i (@subabstoshow) {
						$i =~ s/[ aA]//g;
						if ($i =~ /(\d+?)\D+?(\d+?)/) {
							my @subseqnum = ($1..$2);
							push (@subabstoshow,@subseqnum);
							$i = 0;
							@subabstoshow = sort {$a <=> $b} @subabstoshow;
						}
					}
					for my $i (@subabstoshow) {
						if ($i > 0) {
							print STDERR "Following is the abstract $i \~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\r\n\r\n";
							print STDERR "$i. $abstxtlist[$i-1]\r\n\r\n";
							print STDERR "Use this for output?\r\n";
							print STDERR "* 'Y' or 'y': Yes\r\n";
							print STDERR "* Any other key: Next\r\n";
							my $subsubanswer = <STDIN>;
							$subsubanswer =~ s/[\r\n]//g;
							if ($subsubanswer eq 'Y' || $subsubanswer eq 'y') {
								push (@finalallinfo,$allinfo[$i-1]);
								print STDERR "\r\nAdding it to the list for final output and proceeding\r\n\r\n";
							}
						}
					}
				} elsif ($subanswer =~ /\d+/i) {
					my @paperstoadd = split (/[\s\,\;\:]/,$subanswer);
					for my $i (@paperstoadd) {
						$i =~ s/ //g;
						if ($i =~ /(\d+?)\D+?(\d+?)/) {
							my @subseqnum = ($1..$2);
							push (@paperstoadd,@subseqnum);
							$i = 0;
							@paperstoadd = sort {$a <=> $b} @paperstoadd;
						}
					}
					print STDERR "\r\nAdding them to the list for final output and proceeding\r\n\r\n";
					for my $i (@paperstoadd) {
						if ($i != 0) {
							push (@finalallinfo,$allinfo[$i-1]);
						}
					}
				}
			} elsif ($answer =~ /\d+/i) {
				my @paperstoadd = split (/[\s\,\;\:]/,$answer);
				for my $i (@paperstoadd) {
					$i =~ s/ //g;
					if ($i =~ /(\d+)\D+?(\d+)/) {
						my @subseqnum = ($1..$2);
						push (@paperstoadd,@subseqnum);
						$i = 0;
						@paperstoadd = sort {$a <=> $b} @paperstoadd;
					}
				}
				print STDERR "\r\nAdding them to the list for final output and proceeding\r\n\r\n";
				for my $i (@paperstoadd) {
					if ($i != 0) {
						push (@finalallinfo,$allinfo[$i-1]);
					}
				}
			}
		}
	} else {
		print STDERR "$refkey (line $refkeyindex) has no hit\r\n";
		print STDERR "Adding '*' to the keyword and proceeding\r\n\r\n";
		$fmtoutput ='*'.$orgrefkey;
		push (@finalallinfo,$fmtoutput);
	}
}


##Outputting
sub outputting {
	if (!$mstext) {
		print STDERR "\r\nOutput start \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\r\n\r\n";
		if ($opts{order} !~ /num|index|name|author|year|pm|title|save/i && $opts{fldfmt} !~ /febs|npg/i) {
			for my $m (0..$#finalallinfo) {
				my $index = $m+1;
				print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
				print STDOUT "$finalallinfo[$m]\r\n";
			}
		} elsif ($opts{order} !~ /num|index|name|author|year|pm|title|save/i && $opts{fldfmt} =~ /febs/i) {
			for my $m (0..$#finalallinfo) {
				my $index = $m+1;
				print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
				print STDOUT "[$index] $finalallinfo[$m]\r\n";
			}
		} elsif ($opts{order} !~ /num|index|name|author|year|pm|title|save/i && $opts{fldfmt} =~ /npg/i) {
			for my $m (0..$#finalallinfo) {
				my $index = $m+1;
				print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
				print STDOUT "$index. $finalallinfo[$m]\r\n";
			}
		} elsif ($opts{order} eq 'rawsave' && $opts{fldfmt} !~ /febs|npg/i) {
			for my $m (@finalallinfo) {
				print RFO "$m\r\n";
			}
		} elsif ($opts{order} eq 'rawsave' && $opts{fldfmt} =~ /febs/i) {
			for my $m (0..$#finalallinfo) {
				my $index = $m+1;
				print RFO "[$index] $finalallinfo[$m]\r\n";
			}
		} elsif ($opts{order} eq 'rawsave' && $opts{fldfmt} =~ /npg/i) {
			for my $m (0..$#finalallinfo) {
				my $index = $m+1;
				print RFO "$index. $finalallinfo[$m]\r\n";
			}
		} elsif ($opts{order} =~ /name|author|year|title/i) {
			my @orderout;
			if ($opts{order} !~ /\=r/i) {
				for my $m (sort { $fmtout_sval{$a} cmp $fmtout_sval{$b} } keys %fmtout_sval) {
					if (grep { /\Q$m\E/ } @finalallinfo) {
						push (@orderout,$m);
					}
				}
			} else {
				for my $m (sort { $fmtout_sval{$b} cmp $fmtout_sval{$a} } keys %fmtout_sval) {
					if (grep { /\Q$m\E/ } @finalallinfo) {
						push (@orderout,$m);
					}
				}
			}
			if ($opts{fldfmt} =~ /febs/i && $opts{order} ne 'namesave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDOUT "[$index] $orderout[$m]\r\n";
				}
			} elsif ($opts{fldfmt} =~ /npg/i && $opts{order} ne 'namesave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDOUT "$index. $orderout[$m]\r\n";
				}
			} elsif ($opts{order} ne 'namesave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDOUT "$orderout[$m]\r\n";
				}
			} elsif ($opts{fldfmt} =~ /febs/i && $opts{order} eq 'namesave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print RFO "[$index] $orderout[$m]\r\n";
				}
			} elsif ($opts{fldfmt} =~ /npg/i && $opts{order} eq 'namesave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print RFO "$index. $orderout[$m]\r\n";
				}
			} elsif ($opts{order} eq 'namesave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print RFO "$orderout[$m]\r\n";
				}
			}
		} elsif ($opts{order} =~ /num|index|pm/i) {
			my @orderout;
			if ($opts{order} !~ /\=r/i) {
				for my $m (sort { $fmtout_sval{$a} <=> $fmtout_sval{$b} } keys %fmtout_sval) {
					if (grep { /\Q$m\E/ } @finalallinfo) {
						push (@orderout,$m);
					}
				}
			} else {
				for my $m (sort { $fmtout_sval{$b} <=> $fmtout_sval{$a} } keys %fmtout_sval) {
					if (grep { /\Q$m\E/ } @finalallinfo) {
						push (@orderout,$m);
					}
				}
			}
			if ($opts{fldfmt} =~ /febs/i && $opts{order} ne 'numsave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDOUT "[$index] $orderout[$m]\r\n";
				}
			} elsif ($opts{fldfmt} =~ /npg/i && $opts{order} ne 'numsave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					my $index = $m+1;
					print STDOUT "$index. $orderout[$m]\r\n";
				}
			} elsif ($opts{order} ne 'numsave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDOUT "$orderout[$m]\r\n";
				}
			} elsif ($opts{fldfmt} =~ /febs/i && $opts{order} eq 'numsave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print RFO "[$index] $orderout[$m]\r\n";
				}
			} elsif ($opts{fldfmt} =~ /npg/i && $opts{order} eq 'numsave') {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print RFO "$index. $orderout[$m]\r\n";
				}
			} elsif ($opts{order} eq 'numsave') {
				for my $m (0..$#orderout) {
					print RFO "$orderout[$m]\r\n";
				}
			}
		}
		print STDERR "\r\n\r\nOutput end \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\r\n\r\n";
	} else {
		print STDERR "\r\nReference start \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\r\n\r\n";
		if ($opts{order} !~ /num|index|name|author|year|pm|title/i && $opts{fldfmt} !~ /febs|npg/i) {
			for my $m (0..$#finalallinfo) {
				my $index = $m+1;
				print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
				print STDERR "$finalallinfo[$m]\r\n";
			}
		} elsif ($opts{order} !~ /num|index|name|author|year|pm|title/i && $opts{fldfmt} =~ /febs/i) {
			for my $m (0..$#finalallinfo) {
				my $index = $m+1;
				print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
				print STDERR "[$index] $finalallinfo[$m]\r\n";
			}
		} elsif ($opts{order} !~ /num|index|name|author|year|pm|title/i && $opts{fldfmt} =~ /npg/i) {
			for my $m (0..$#finalallinfo) {
				my $index = $m+1;
				print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
				print STDERR "$index. $finalallinfo[$m]\r\n";
			}
		} elsif ($opts{order} =~ /name|author|year|title/i) {
			my @orderout;
			if ($opts{order} !~ /\=r/i) {
				for my $m (sort { $fmtout_sval{$a} cmp $fmtout_sval{$b} } keys %fmtout_sval) {
					if (grep { /\Q$m\E/ } @finalallinfo) {
						push (@orderout,$m);
					}
				}
			} else {
				for my $m (sort { $fmtout_sval{$b} cmp $fmtout_sval{$a} } keys %fmtout_sval) {
					if (grep { /\Q$m\E/ } @finalallinfo) {
						push (@orderout,$m);
					}
				}
			}
			if ($opts{fldfmt} =~ /febs/i) {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDERR "[$index] $orderout[$m]\r\n";
				}
			} elsif ($opts{fldfmt} =~ /npg/i) {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDERR "$index. $orderout[$m]\r\n";
				}
			} else {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDERR "$orderout[$m]\r\n";
				}
			}
		} elsif ($opts{order} =~ /num|index|pm/i) {
			my @orderout;
			if ($opts{order} !~ /\=r/i) {
				for my $m (sort { $fmtout_sval{$a} <=> $fmtout_sval{$b} } keys %fmtout_sval) {
					if (grep { /\Q$m\E/ } @finalallinfo) {
						push (@orderout,$m);
					}
				}
			} else {
				for my $m (sort { $fmtout_sval{$b} <=> $fmtout_sval{$a} } keys %fmtout_sval) {
					if (grep { /\Q$m\E/ } @finalallinfo) {
						push (@orderout,$m);
					}
				}
			}
			if ($opts{fldfmt} =~ /febs/i) {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDERR "[$index] $orderout[$m]\r\n";
				}
			} elsif ($opts{fldfmt} =~ /npg/i) {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDERR "$index. $orderout[$m]\r\n";
				}
			} else {
				for my $m (0..$#orderout) {
					my $index = $m+1;
					print STDERR "\r\nReference $index ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
					print STDERR "$orderout[$m]\r\n";
				}
			}
		}
		print STDERR "\r\nReference end \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\r\n\r\n";
		print STDERR "\r\nReordering these references using the manuscript text\r\n\r\n";
	}
	if (@finalallinfo && $opts{fldfmt} =~ /DB(\=\S+){0,1}/) {
		my $dbfile = $1;
		my @dbtitlel;
		my @dbpmidl;
		my $dbpnum = $#finalallinfo + 1;
		$dbfile =~ s/^\=//;
		print STDERR "Option '-f DB' was selected\r\n\r\n";
		if ($dbfile =~ /\w/) {
			print STDERR "Add the above $dbpnum references to the file $dbfile?\r\n";
			print STDERR " * 'Y' or 'y': Yes\r\n * Any other key: skips this step\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			$answer =~ s/^ +| +$//g;
			if ($answer eq 'Y' || $answer eq 'y') {
				sub dbdataaddition {
					print "$dbfile test\n";
					if (open (DBF, "< $dbfile")) {
						open (DBF, "< $dbfile");
						while (my $line = <DBF>) {
							my @dbfields = split (/\t/,$line);
							my $dbpmid = $dbfields[7];
							$dbpmid =~ s/^ +| +$//g;
							push (@dbpmidl, $dbpmid);
						}
						close (DBF);
						open (DBF, ">> $dbfile");
					} else {
						open (DBF, "> $dbfile");
					}
					print STDERR "\r\nAdding the references to $dbfile\r\n\r\n";
					for my $data (@finalallinfo) {
						my @dataf = split (/\t/,$data);
						my $pmidkey = $dataf[7];
						$pmidkey =~ s/http.+\/(\d+)\/{0,1}/$1/;
						$pmidkey =~ s/^ +| +$//g;
						$pmidkey =~ s/\W/./;
						if (!grep { /$pmidkey/is } @dbpmidl ) {
							if ($opts{fldfmt} =~ /\=MAC/) {
								print DBF "$data\r";
							} elsif ($opts{fldfmt} =~ /\=UNI|\=LIN/) {
								print DBF "$data\n";
							} else {
								print DBF "$data\r\n";
							}
						}
					}
					close (DBF);
				}
				dbdataaddition();
			} else {
				print STDERR "\r\nSkipping\r\n\r\n";
			}
		} else {
			print STDERR "Input a path to the file to which references are added,\r\nor any other key to skip this step\r\n\r\n";
			$dbfile = <STDIN>;
			$dbfile =~ s/[\r\n]//g;
			$dbfile =~ s/^ +| +$//g;
			if ($dbfile =~ /\w/) {
				dbdataaddition();
			} else {
				print STDERR "\r\nSkipping\r\n\r\n";
			}
		}
	}
}

#Loading a manuscript file
sub msloading {
	if (open (MSF, "< $opts{order}")){
		undef $/;
		open (MSF, "< $opts{order}");
		$mstext = <MSF>;
		close (MSF);
		print STDERR "\r\nManuscript text was loaded for ordering references\r\n\r\n";
		$/ = "\n";
	}
}





#Processing starts from here





#Loading input files
if (open (INF,"< $ARGV[0]")) {
	undef $/;
	open (INF,"< $ARGV[0]");
	$inputref = <INF>;
	close (INF);
	$/ = "\n";
	if (!$opts{browse}) {
		print STDERR "$inputref\r\n\r\n";
		print STDERR "The above input was loaded \~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\r\n\r\n";
	}
}


#browsing mode
if ($opts{browse}) {
	if (!$inputref) {
		print STDERR "Option -b was selected but no file to browse is found\r\n\r\n";
		print STDERR "Ending program\r\n";
		exit;
	} else {
		msloading();
		my @dballdata = split (/[\r\n]+/,$inputref);
		print STDERR "Browsing mode\r\n! Options -s, -x, -a and -d are all ignored\r\n";
		$opts{search} = 0;
		$opts{xmlcorr} = 0;
		$opts{abscorr} = 0;
		$opts{delimit} = 0;
		while ($refkey ne 'Q' || $refkey ne 'q') {
			$refkey = '';
			print STDERR "\r\nInput keywords in regular expression\r\n";
			print STDERR "(case-insensitive; space is converted to \".*?\" for AND search)\r\n";
			print STDERR "! Results can be saved in a file by either\r\n   '>[file name]' (to make a new file) or\r\n   '>>[file name]' (for postscript)\r\n";
			print STDERR "! Either 'Q' or 'q' ends browsing\r\n\r\n";
			$refkey = <STDIN>;
			$refkey =~ s/[\r\n]//g;
			if ($refkey eq 'Q' || $refkey eq 'q') {
				last;
			}
			valresetting();
			@finalallinfo = ();
			my $optfileh;
			if ($refkey =~ /\>{1,2} *?\S+/s) {
				$optfileh = $&;
				$refkey =~ s/\Q$optfileh\E//;
			}
			$refkey =~ s/^ +| +$//g;
			$refkey =~ s/ /.*?/g;
			for my $i (@dballdata) {
				if ($refkey =~ /\S/ && $i =~ /$refkey/is ) {
					my @dfs = split (/\t/,$i);
					$author = $dfs[0];
					$title = $dfs[1];
					$year = $dfs[2];
					$journal = $dfs[3];
					$volume = $dfs[4];
					$issue = $dfs[5];
					$pages = $dfs[6];
					$pmid = $dfs[7];
					$pmid =~ s/http.+\/(\d+)\/{0,1}/$1/;
					$pmcid = $dfs[8];
					$pmcid =~ s/http.+\/(PMC\d+)\/{0,1}/$1/i;
					$doi = $dfs[9];
					$doi =~ s/http.+org\/(\S+)\/{0,1}/$1/i;
					$attribute = $dfs[10];
					$institute = $dfs[11];
					$abstract = $dfs[12];
					formatting();
					push (@finalallinfo,$fmtoutput);
				}
			}
			if ($optfileh) {
				open (RFO, $optfileh);
				if ($opts{order} =~ /name|author|year|title/i) {
					$opts{order} = 'namesave';
				} elsif ($opts{order} =~ /num|index|pm/i) {
					$opts{order} = 'numsave';
				} else {
					$opts{order} = 'rawsave';
				}
				outputting();
				close (RFO);
			} else {
				outputting();
			}
		}
		if (!$mstext) {
			print STDERR "\r\nEnding program\r\n";
			exit;
		} else {
			$refkey = '';
			print STDERR "\r\nOrdering the above references using the manuscript file\r\n\r\n";
		}
	}
}



#Checking option compatibility
if (($opts{search} && $opts{abscorr}) || ($opts{search} && $opts{xmlcorr}) || ($opts{search} && $opts{delimit}) || ($opts{abscorr} && $opts{xmlcorr}) || ($opts{abscorr} && $opts{delimit}) || ($opts{xmlcorr} && $opts{delimit})) {
	print STDERR "Options -s, -x, -a and -d are incompatible with each other\r\n\r\n";
	print STDERR "Please try again\r\n\r\nEnding program\r\n";
	exit;
}


if (!$opts{browse}) {
	msloading();
}


#Redirecting in case of no input

if (!$inputref && !$mstext && !$opts{search} && !$opts{xmlcorr} && !$opts{abscorr} && !$opts{delimit}) {
	print STDERR "No input was found\r\n";
	print STDERR "Perform reference and/or manuscript correction?\r\n";
	print STDERR " * 'S' or 's': starts keyword search mode\r\n";
	print STDERR " * 'A' or 'a': starts PubMed abstract correction mode\r\n";
	print STDERR " * 'D' or 'd': starts delimiter mode\r\n";
	print STDERR " * 'M' or 'm': starts generating references from a manuscript file\r\n   (only PubMed search will be used to get references)\r\n";
	print STDERR " * Any other key: ends program\r\n\r\n";
	my $answer = <STDIN>;
	$answer =~ s/[\r\n]//g;
	if ($answer eq 'S' || $answer eq 's') {
		$opts{search} = 1;
		print STDERR "\r\nActivating the -s option\r\n\r\n";
	} elsif ($answer eq 'A' || $answer eq 'a') {
		$opts{abscorr} = 1;
		print STDERR "\r\nActivating the -a option\r\n\r\n";
	} elsif ($answer eq 'D' || $answer eq 'd') {
		$opts{delimit} = 1;
		print STDERR "\r\nActivating the -d option\r\n\r\n";
	} elsif ($answer eq 'M' || $answer eq 'm') {
		print STDERR "Input a path to a manuscript file\r\n\r\n";
		$opts{order} = <STDIN>;
		$opts{order} =~ s/[\r\n]//g;
		msloading();
		if (!$mstext) {
			print STDERR "Manuscript file cannot be found\r\n\r\n";
			print STDERR "Ending program\r\n";
			exit;
		}
	} else {
		print STDERR "Ending program\r\n";
		exit;
	}
}


#Trying to get information about paper only from the given reference list
if ($inputref &&  !$opts{search} && !$opts{xmlcorr} && !$opts{abscorr} && !$opts{delimit}) {
	print STDERR "None of the options -s, -a and -d was selected\r\n";
	print STDERR "Generating a reference list using possible information\r\n\r\n";
	if (!$opts{fldfmt}) {
		$opts{fldfmt} = 'raw';
	}
	if ($opts{fldfmt} !~ /raw|unchange/i) {
		pmjlisting();
		spcnlisting();
	}
	@refkeylist = split (/[\r\n]+/, $inputref);
	for my $refkey (@refkeylist) {
		valresetting();
		$orgrefkey = $refkey;
		$refkey =~ s/\r\n$|\n$|\r$//;
		if ($refkey =~ /^.*?(\d+)/s) {
			$indexkey = $1;
		}
		if ($refkey =~ /pmid\D+(\d+)/i){
			$pmid = $1;
			$refkey =~ s/$1/./;
		}
		if ($refkey =~ /pmc\d+/i) {
			$pmcid = $&;
			$refkey =~ s/$&/./;
		}
		if ($refkey =~ /doi[\W]+?([\/\.\w\d]+)/i) {
			$doi = $1;
			$refkey =~ s/$1/./;
		}
		if ($refkey =~ /([12]\d{3}[a-zA-Z]{0,1})( \w+){0,1}/s) {
			$year = $1;
			$date = $2;
			$refkey =~ s/\({0,1}$year\){0,1}( \w+){0,1}/YEARISHERE/;
		}
		
		my @refkeylist1 = split (/YEARISHERE/, $refkey);
		for my $j (@refkeylist1) {
			$j =~ s/^ +| +$//g;
			$j =~ s/^([A-Z]+?)\./$1/;
			$j =~ s/([A-Z]+?)\.([\,\;])/$1$2/g;
			$j =~ s/([A-Z]+?)\. and/$1 and/g;
			$j =~ s/([\,\;]) {0,1}([A-Z]+?)\./$1 $2/g;
			for (1..100) {
				$j =~ s/([A-Z]+?)\. {0,1}([A-Z][^a-z ])/$1$2/g;
			}
			my @refkeylist2 = split (/\./, $j);
			for my $k (0..$#refkeylist2) {
				$refkeylist2[$k] =~ s/^ +| +$//g;
				if ($refkeylist2[$k] =~ /et al|^[A-Z][a-z\'\-\?][A-Za-z\'\-\?]*( [A-Z][a-z\'\-\?][A-Za-z\'\-\?]*){0,}\,{0,1} *[A-Z]+[\,\; and].*[A-Z][a-z\'\-\?][A-Za-z\'\-\?]*( [A-Z][a-z\'\-\?][A-Za-z\'\-\?]*){0,}\,{0,1} [A-Z]+[ Jr\,]*$|^[A-Z]+\,{0,1} [A-Z][a-z\'\-\?][A-Za-z\'\-\?]*( [A-Z][a-z\'\-\?][A-Za-z\'\-\?]*){0,}[\,\; and].*[A-Z]+\,{0,1} [A-Z][a-z\'\-\?][A-Za-z\'\-\?]*( [A-Z][a-z\'\-\?][A-Za-z\'\-\?]*){0,}[ Jr\,]*$|^[A-Z]+ [A-Z][a-z\'\-\?][A-Za-z\'\-\?]*( [A-Z][a-z\'\-\?][A-Za-z\'\-\?]*){0,3}[ Jr\,]*$|^[A-Z][a-z\'\-\?][A-Za-z\'\-\?]*( [A-Z][a-z\'\-\?][A-Za-z\'\-\?]*){0,3} [A-Z]+[ Jr\,]*$/) {
					$author = $refkeylist2[$k];
					if (!$opts{fldfmt} || $opts{fldfmt} =~ /raw|unchange/i) {
						next;
					}
				} elsif ($opts{fldfmt} && $opts{fldfmt} !~ /raw|unchange/i && $refkeylist2[$k] =~ /^\w\S* (\S+ ){3}\S/) {
					for my $l (@allspecies) {
						if ($refkeylist2[$k] =~ /\Q$l\E/i) {
							$title = $refkeylist2[$k];
							$refkey =~ s/$title/TITLEISHERE/;
							last;
						}
					}
				} elsif ($opts{fldfmt} && $opts{fldfmt} !~ /raw|unchange/i) {
					for my $l (@pmjalltitle) {
						if ($refkey =~ /$l/i) {
							$journal = $&;
							$refkey =~ s/$&/\|\!JOURNAL\!\|/;
							last;
						}
					}
				}
				if ($title ne '' && $author ne '') {
					last;
				}
			}
			if ($title ne '' && $author ne '') {
				last;
			}
		}
		if ($journal eq '' && $opts{fldfmt} && $opts{fldfmt} !~ /raw|unchange/i) {
			for my $j (@pmjalltitle) {
				if ($refkey =~ /$j/i) {
					$journal = $&;
					$refkey =~ s/$&/\|\!JOURNAL\!\|/;
					last;
				}
			}
		}
		if ($refkey =~ /\|\!JOURNAL\!\|[\W]*?([\w\-]+)[\.\,\:\;\(\s]+?([\w\-]+)[\.\,\:\;\)\s]+?([\w\-]+)[\W]*?/s) {
			$volume = $1;
			$issue = $2;
			$pages = $3;
			$refkey =~ s/$&/./;
		} elsif ($refkey =~ /\|\!JOURNAL\!\|[\W]*?([\w\-]+)[\W]+?([\w\-]+)[\W]*?/s) {
			$volume = $1;
			$pages = $2;
			$refkey =~ s/$&/./;
		} elsif ($refkey =~ /\|\!JOURNAL\!\|[\W]*?([\w\-]+)[\W]*?/s) {
			$pages = $1;
			$refkey =~ s/$&/./;
		}
		$refkey =~ s/YEARISHERE|TITLEISHERE|\|\!JOURNAL\!\|/./g;
		if ($pages =~ /\-/){
			my ($startpage, $endpage) = split(/\-/,$pages);
			if ($startpage > $endpage){
				my $epdigit = 10**length($endpage);
				my $truncated = int($startpage / $epdigit);
				my $modendpage = $truncated.$endpage;
				$pages = $startpage.'-'.$modendpage;
			}
		}
		if ($author ne '') {
			@authorlist = split (/[\,\;]/,$author);
			for my $j (@authorlist) {
				if ($j =~ /[A-Za-z][a-z\'\-\?]+/) {
					$firstauthor = $j;
					last;
				}
			}
		} else {
			my @furtherskeys = split (/\,|\;|\./, $refkey);
			for my $j (@furtherskeys) {
				$j =~ s/^ +| +$//g;
			}
			my @furtherskeys2 = split (/\.|\;/, $refkey);
			for my $j (@furtherskeys2) {
				$j =~ s/^ +| +$//g;
			}
			
			my @preauthorlist;
			for my $j (@furtherskeys) {
				if ($j =~ /^[A-Za-z][A-Za-z\'\-\?]*$|^[A-Z][A-Za-z\'\-\?]*( [A-Z][A-Za-z\'\-\?]*){0,3}$|[A-Z][A-Za-z\'\-\?]*( [A-Z][A-Za-z\'\-\?]*){0,3} and [A-Z][A-Za-z\'\-\?]*( [A-Z][A-Za-z\'\-\?]*){0,3}$|et al/) {
					push (@preauthorlist, $j);
					$j = '';
				}
			}
			my $curauthor = $preauthorlist[0];
			if ($#preauthorlist >= 1 && $curauthor =~ /^[A-Za-z]$|^[A-Z]+$/ && grep {/ and |et al/} @preauthorlist) {
				for my $j (1..$#preauthorlist) {
					$curauthor = $curauthor.$preauthorlist[$j];
					if ($preauthorlist[$j] =~ /^[A-Za-z][a-z\'\-\?]+/) {
						$refkey =~ s/$preauthorlist[$j]//;
						$curauthor =~ s/$preauthorlist[$j]/ $preauthorlist[$j]/;
						$curauthor =~ s/  / /;
						push (@authorlist, $curauthor);
						$curauthor = '';
					}
				}
				$author = join (', ',@authorlist);
			} elsif ($#preauthorlist >= 1 && $curauthor =~ /^[A-Za-z]$|^[A-Z]+$/) {
				for my $j (1..$#preauthorlist) {
					$curauthor = $curauthor.$preauthorlist[$j];
					if ($preauthorlist[$j] =~ /^[A-Za-z][a-z\'\-\?]+/) {
						$refkey =~ s/$preauthorlist[$j]//;
						$curauthor =~ s/(.*)$preauthorlist[$j]/$preauthorlist[$j] $1/;
						$curauthor =~ s/  / /;
						push (@authorlist, $curauthor);
						$curauthor = '';
					}
				}
				$author = join (', ',@authorlist);
			} elsif ($#preauthorlist >= 1 && grep {/^[A-Za-z]$|^[A-Z]+$/} @preauthorlist) {
				my $lastname = $curauthor;
				for my $j (1..$#preauthorlist) {
					$curauthor = $curauthor.$preauthorlist[$j];
					if ($preauthorlist[$j] =~ /^[A-Za-z][a-z\'\-\?]+/) {
						$refkey =~ s/$preauthorlist[$j]//;
						$curauthor =~ s/$preauthorlist[$j]//;
						$curauthor =~ s/$lastname/$lastname /;
						$curauthor =~ s/  / /;
						push (@authorlist, $curauthor);
						$curauthor = $preauthorlist[$j];
						$lastname = $curauthor;
					}
				}
				$curauthor =~ s/$lastname/$lastname /;
				$curauthor =~ s/  / /;
				if (!grep {/$curauthor/} @authorlist ) {
					push (@authorlist, $curauthor);
				}
				$author = join (', ',@authorlist);
				$author = s/^ \,//;
			} elsif ($#preauthorlist >= 1) {
				$author = join (', ',@preauthorlist);
				for my $j (@preauthorlist) {
					$refkey =~ s/\Q$j\E//;
				}
			} else {
				$author = $curauthor;
				$refkey =~ s/$author//;
			}
			$author =~ s/\, et al/ et al/;
			@authorlist = split (/\,|\;/,$author);
			for my $j (@authorlist) {
				if ($j =~ /[A-Za-z][a-z\'\-\?]+/) {
					$firstauthor = $j;
					last;
				}
			}
			if ($title ne '') {
				my @furtherskeys3 = split (/\.|\;/, $refkey);
				for my $j (@furtherskeys3) {
					$j =~ s/^ +| +$//g;
				}
				for my $j (@furtherskeys3) {
					for my $k (@furtherskeys2) {
						if ($j =~ /^\w\S* (\S+ ){3}\S/ && $k =~ /$j/) {
							$title = $k;
							last;
						}
						if ($title) {
							last;
						}
					}
				}
				for my $j (@furtherskeys3) {
					if ($title && $j =~ /^\S+ ([\S]+ ){50}\S/) {
						$abstract = $j;
					} elsif ($j =~ /^\S+ ([\S]+ ){3}\S/) {
						push (@attributelist,$j);
					}
				}
			}
		}
		formatting();
		push (@finalallinfo,$fmtoutput);
	}
	outputting();
	if (!$mstext) {
		print STDERR "Done\r\n\r\nEnding program\r\n";
		exit;
	}
}


#Keyword search mode
if ($opts{search}) {
	print STDERR "Keyword search mode\r\n\r\n";
	if (!$opts{fldfmt}) {
		$opts{fldfmt} = 'default';
	}
	while ($refkey ne 'Q' || $refkey ne 'q') {
		if (!$inputref) {
			print STDERR "Input keywords for PubMed search\r\n";
			print STDERR "! 'M' or 'm' starts multiple keyword mode\r\n";
			print STDERR "! 'Q' or 'q' ends searching\r\n\r\n";
			$refkey = <STDIN>;
			$refkey =~ s/[\r\n]//g;
			if ($refkey eq 'Q' || $refkey eq 'q') {
				last;
			}
			@refkeylist = ();
			if ($refkey eq 'M' || $refkey eq 'm') {
				print STDERR "\r\nMultiple keyword mode\r\n\r\nInput a keyword in each line, then\r\n  Ctrl+Z followed by enter (for Windows),\r\n  Ctrl+D (for Linux), or\r\n  'END' followed by enter (for either Windows or Linux)\r\n\r\n";
				$/ = 'END';
				$refkey = <STDIN>;
				@refkeylist = split (/[\r\n]+/,$refkey);
				$/ = "\n";
				my $fakeanswer = <STDIN>; #this is necessary for multiple keyword mode
			} else {
				push (@refkeylist,$refkey);
			}
		} else {
			@refkeylist = split (/[\r\n]+/, $inputref);
		}
		@finalallinfo = ();
		for my $h (0..$#refkeylist) {
			$refkeylist[$h] =~ s/[\r\n]$|END$//g;
			$refkeylist[$h] =~ s/^ +| +$//g;
			if ($refkeylist[$h] !~ /\w/) {
				next;
			}
			valresetting();
			$refkeyindex = $h+1;
			$orgrefkey = $refkeylist[$h];
			$refkey = $refkeylist[$h];
			if ($refkey =~ /pmid\D*?(\d+)/i){
				$refkey = $1;
			} elsif ($refkey =~ /(pmc\d+)/i) {
				$refkey = $1;
			} elsif ($refkey =~ /doi[\s\.\:\,\;\|\=]+?([\/\.\w\d]+)/i) {
				$refkey = $1;
			} else {
				$refkey =~ s/[^\w\d\s]/\+/g;
				$refkey =~ s/\s/\+/g;
			}
			print STDERR "\r\nLine $refkeyindex: uses the keyword \'$refkey\' \~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\r\n\r\n";
			pmsearching();
		}
		outputting();
		if ($inputref) {
			last;
		}
	}
	if (!$mstext) {
		print STDERR "\r\nDone\r\n\r\nEnding program\r\n";
		exit;
	}
}


#PubMed XML correction mode
if ($opts{xmlcorr}) {
	print STDERR "PubMed XML correction mode\r\n\r\n";
	if (!$opts{fldfmt}) {
		$opts{fldfmt} = 'default';
	}
	if (!$inputref) {
		$/ = 'END';
		print STDERR "Input PubMed XML-formatted texts and then either Ctrl+D or 'END'\r\n\r\n";
		$pmabstract = <STDIN>;
		$pmabstract =~ s/END$//g;
	} else {
		$pmabstract = $inputref;
	}
	pmxmlcorrection();
	@finalallinfo = @allinfo;
	outputting();
	if (!$mstext) {
		print STDERR "Done\r\n\r\nEnding program\r\n";
		exit;
	}
}



#PubMed abstract text correction mode
if ($opts{abscorr}) {
	print STDERR "PubMed abstract text correction mode\r\n\r\n";
	if (!$opts{fldfmt}) {
		$opts{fldfmt} = 'default';
	}
	if (!$inputref) {
		$/ = 'END';
		print STDERR "Input PubMed abstract texts and then either Ctrl+D or 'END'\r\n\r\n";
		$pmabstract = <STDIN>;
		$pmabstract =~ s/END$//g;
	} else {
		$pmabstract = $inputref;
	}
	pmabscorrection();
	@finalallinfo = @allinfo;
	outputting();
	if (!$mstext) {
		print STDERR "Done\r\n\r\nEnding program\r\n";
		exit;
	}
}


if ($opts{delimit}) {
	print STDERR "Delimiter mode\r\n\r\n";
	if (!$inputref) {
		print STDERR "What to do?\r\n\r\n";
		print STDERR " * 'P' or 'p': subsequently asks to input references\r\n";
		print STDERR " * Path to a reference file: uses the file to proceed\r\n";
		print STDERR " * Any other key: ends program\r\n\r\n";
		my $inputkey = <STDIN>;
		$inputkey =~ s/[\r\n]//g;
		if (open (INF,"< $inputkey")) {
			undef $/;
			open (INF,"< $inputkey");
			$inputref = <INF>;
			close (INF);
			$/ = "\n";
			print STDERR "\r\n$inputref\r\n\r\n";
			print STDERR "The above input was loaded \~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\r\n\r\n";
		} elsif ($inputkey eq 'P' || $inputkey eq 'p') {
			print STDERR "\r\nInput references and then either Ctrl+D or 'END'\r\n\r\n";
			$/ = 'END';
			$inputref = <STDIN>;
			$inputref =~ s/END$//g;
			$/ = "\n";
			my $fakeanswer = <STDIN>;
			print STDERR "\r\nOK. Proceeding\r\n\r\n";
		} else {
			if (!open (INF,"< $inputkey")) {
				print STDERR "\r\nReference file cannot be found\r\n";
			}
			print STDERR "\r\nEnding program\r\n";
			exit;
		}
	}
	$inputref =~ s/\r\n$|\n$|\r$//g;
	print STDERR "Input delimiters. For example ...\r\n\r\n";
	print STDERR "F1 (F2) F3. F4, F5 RS=';'\r\n\r\n";
	print STDERR " Tsugama (2018) Refmaker. Perl, 1 ; Diceman (2015) Memory in. USA, 2 \r\n";
	print STDERR "   ||      ||      ||      ||   ||    ||      ||       ||      ||  ||\r\n";
	print STDERR " Field 1   F2      F3      F4   F5    F1      F2       F3      F4  F5\r\n";
	print STDERR "|----------- Record 1 ------------|----------- Record 2 ------------|\r\n\r\n\r\n";
	print STDERR "! to separate records and fields as the above\r\n\r\n";
	print STDERR "! RS='' and PF='' set the record separator and the field prefix, respectively\r\n";
	print STDERR "  (RS='\\n' PF='F' is the default)\r\n";
	print STDERR "! FS='(comma-delimited characters)' can set field separators\r\n";
	print STDERR "  (FS=' (,) ,. ,\, ' is equivalent to F1 (F2) F3. F4, F5)\r\n\r\n";
	print STDERR "! '!FJ1, !FJ2 ...' can be used as fields for journal names\r\n";
	print STDERR "  (Cafebr then tries to find a journal name in corresponding fields)\r\n\r\n";
	print STDERR "Delimiters are:\r\n\r\n";
	my $delimiter = <STDIN>;
	$delimiter =~ s/[\r\n]//g;
	my $prefix = 'F';
	my $inputtemplate;
	my @fslist;
	my $frexkey = 0;
	if ($delimiter =~ /RS *?\= *?\'(.+?)\' *?\= *?REX/s) {
		@refkeylist = split (/$1/, $inputref);
		$delimiter =~ s/\Q$&\E//;
		print STDERR "\r\nInput was split into records by \'$1\'\r\n\r\n";
	} elsif ($delimiter =~ /RS *?\= *?\'(.+?)\'/s) {
		@refkeylist = split (/\Q$1\E/, $inputref);
		$delimiter =~ s/\Q$&\E//;
		print STDERR "\r\nInput was split into records by \'$1\'\r\n\r\n";
	} else {
		@refkeylist = split (/[\r\n]+/, $inputref);
		print STDERR "\r\nInput was split into records by line breaks (i.e., line = record)\r\n\r\n";
	}
	if ($delimiter =~ /PF *?\= *?\'(.+)\'/s && $1 ne 'F') {
		$prefix = $1;
		$delimiter =~ s/\Q$&\E//;
		print STDERR "\r\nPrefix was changed from F to $prefix\r\n\r\n";
	}
	if ($delimiter =~ / *?\= *?REX/s) {
		$frexkey = 1;
		$delimiter =~ s/\Q$&\E//;
	}
	if ($delimiter =~ /FS *?\= *?\'(.+)\'/s) {
		$delimiter = $1;
		$delimiter =~ s/\\\,/!HEREISCOMMA!/g;
		@fslist = split (/\,/, $delimiter);
		$inputtemplate = $delimiter;
		$inputtemplate =~ s/^|$/,/g;
		for my $i (1..1000) {
			my $tmpfieldkey = $prefix.$i;
			$inputtemplate =~ s/\,/$tmpfieldkey/;
		}
		$inputtemplate =~ s/\!HEREISCOMMA\!/,/g;
		$inputtemplate =~ s/^F\d+ *(\!FJ\d*)/$1/g;
		$inputtemplate =~ s/(\!FJ\d*) *F\d+/$1/g;
	} elsif ($delimiter =~ /\Q$prefix\E\d|\!FJ/) {
		$delimiter =~ s/^ +| +$//g;
		$delimiter =~ s/^\'|\'$//g;
		$inputtemplate = $delimiter;
		$delimiter =~ s/^ *\Q$prefix\E\d+|^ *\!FJ\d*|\Q$prefix\E\d+ *$|\!FJ\d* *$//g;
		@fslist = split (/\Q$prefix\E\d+|\!FJ\d*/,$delimiter);
	} else {
		print STDERR "\r\nInput for field separotors may not be good\r\n";
		print STDERR "Proceeding anyway\r\n\r\n";
	}
	print STDERR "Field separotors were set\r\n\r\n";
	if ($inputtemplate =~ /\!FJ/) {
		pmjlisting();
	}
	$refkey = $refkeylist[0];
	my %fields;
	my @tmpfslist = @fslist;
	my $tmpinputt = $inputtemplate;
	my @fkeylist;
	my @fvallist;
	my $outkey=0;
	sub fieldsetting {
		for my $i (0..$#tmpfslist) {
			$tmpfslist[$i] =~ s/\!HEREISCOMMA\!/,/g;
			my $fieldkey;
			my $fieldvalue;
			if (!$frexkey) {
				if ($tmpinputt =~ /^ *?(\!FJ\d*).*?\Q$tmpfslist[$i]\E/s) {
					$fieldkey = $1;
					$tmpinputt =~ s/^ *?\!FJ\d*.*?\Q$tmpfslist[$i]\E//;
					$fields{$fieldkey} = 0;
					for my $j (@pmjalltitle) {
						if ($refkey =~ /$j/i) {
							$fieldvalue = $&;
							$refkey =~ s/^.*?\Q$fieldvalue\E*?\Q$tmpfslist[$i]\E//;
							$fields{$fieldkey} = $fieldvalue;
							last;
						} 
					}
					if (!$fields{$fieldkey}) {
						$refkey =~ s/^(.*?)\Q$tmpfslist[$i]\E//s;
						$fieldvalue = $1;
						$fieldvalue =~ s/^ +| +$//;
						$fields{$fieldkey} = $fieldvalue;
					}
					push (@fkeylist,$fieldkey);
					push (@fvallist,$fieldvalue);
					
				} else {
					$tmpinputt =~ s/^.*?(\Q$prefix\E\d+).*?\Q$tmpfslist[$i]\E//s;
					$fieldkey = $1;
					$refkey =~ s/^(.*?)\Q$tmpfslist[$i]\E//s;
					$fieldvalue = $1;
					$fieldvalue =~ s/^ +| +$//;
					$fields{$fieldkey} = $fieldvalue;
					push (@fkeylist,$fieldkey);
					push (@fvallist,$fieldvalue);
				}
			} else {
				if ($tmpinputt =~ /^ *?(\!FJ\d*).*?$tmpfslist[$i]/s) {
					$fieldkey = $1;
					$tmpinputt =~ s/^ *?\!FJ\d*.*?$tmpfslist[$i]//;
					$fields{$fieldkey} = 0;
					for my $j (@pmjalltitle) {
						if ($refkey =~ /$j/i) {
							$fieldvalue = $&;
							$refkey =~ s/^.*?$fieldvalue*?$tmpfslist[$i]//;
							$fields{$fieldkey} = $fieldvalue;
							last;
						} 
					}
					if (!$fields{$fieldkey}) {
						$refkey =~ s/^(.*?)$tmpfslist[$i]//s;
						$fieldvalue = $1;
						$fieldvalue =~ s/^ +| +$//;
						$fields{$fieldkey} = $fieldvalue;
					}
					push (@fkeylist,$fieldkey);
					push (@fvallist,$fieldvalue);
					
				} else {
					$tmpinputt =~ s/^.*?(\Q$prefix\E\d+).*?$tmpfslist[$i]//s;
					$fieldkey = $1;
					$refkey =~ s/^(.*?)$tmpfslist[$i]//s;
					$fieldvalue = $1;
					$fieldvalue =~ s/^ +| +$//;
					$fields{$fieldkey} = $fieldvalue;
					push (@fkeylist,$fieldkey);
					push (@fvallist,$fieldvalue);
				}
			}
		}
		if ($tmpinputt =~ /\Q$prefix\E\d+|\!FJ\d*/) {
			$fields{$&} = $refkey;
			push (@fkeylist,$tmpinputt);
			push (@fvallist,$refkey);
		}
	}
	fieldsetting();
	
	
	my $fieldnum = $#fkeylist + 1;
	print STDERR "First record was separated into the following $fieldnum fields, for example ~~~~~~~~~~\r\n\r\n";
	for my $i (0..$#fkeylist) {
		my $curfnum = $i +1;
		print STDERR "Field $curfnum ($fkeylist[$i]) -> $fvallist[$i]\r\n";
	}
	print STDERR "\r\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
	my $fieldnum = $inputtemplate;
	$fieldnum = ($fieldnum =~ s/\Q$prefix\E\d+//g);
	my @fieldstoget;
	my $outputtemplate;
	my $prefix2;
	if (!grep { /$opts{fldfmt}/i } @fmtlist) {
		print STDERR "What to do?\r\n\r\n";
		print STDERR " * Providing an output format to proceed\r\n";
		print STDERR "     For example, F5. F4 is F3, by <b>F1</b>\r\n";
		print STDERR " * 'F' or 'f': uses a preset format\r\n";
		print STDERR " * 'Q' or 'q': ends program\r\n\r\n";
		my $answer = <STDIN>;
		$answer =~ s/[\r\n]//g;
		if ($answer eq 'Q' || $answer eq 'q') {
			print STDERR "\r\nEnding program\r\n";
			exit;
		} elsif ($answer eq 'F' || $answer eq 'f') {
			sub formatoptsetting {
				print STDERR "\r\nWhich preset format to use?\r\n\r\n";
				$answer = <STDIN>;
				$answer =~ s/[\r\n]//g;
				if (!grep { /$answer/i } @fmtlist) {
					print STDERR "\r\nProvided format cannot be found in the preset format list\r\n";
					print STDERR "Try again\r\n\r\n";
					$answer  = <STDIN>;
					$answer =~ s/[\r\n]//g;
					if (!grep { /$answer/i } @fmtlist) {
						print STDERR "\r\nProvided format cannot be found in the preset format list\r\n";
						print STDERR "Using default output format\r\n";
						$opts{fldfmt} = 'default';
					} else {
						$opts{fldfmt} = $answer;
						print STDERR "\r\nOutput format was set\r\n";
					}
				} else {
					$opts{fldfmt} = $answer;
					print STDERR "\r\nOutput format was set\r\n";
				}
			}
			formatoptsetting();
		} elsif ($answer !~ /\Q$prefix\E\d/ && $answer !~ / {0,1}\= {0,1}NUM/s) {
			print STDERR "\r\nInvalid input\r\n";
			print STDERR "Try providing an output format again\r\n";
			$answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'Q' || $answer eq 'q' ) {
				print STDERR "\r\nEnding program\r\n";
				exit;
			} elsif ($answer eq 'F' || $answer eq 'f') {
				formatoptsetting();
			} elsif ($answer !~ /\Q$prefix\E\d/ && $answer !~ / {0,1}\= {0,1}NUM/s) {
				print STDERR "\r\nInvalid input\r\n";
				print STDERR "Ending program\r\n";
				exit;
			} else {
				if ($answer =~ / {0,1}\= {0,1}NUM/s) {
					$outkey = 1;
					$answer =~ s/\Q$&\E//;
					if ($answer =~ /PF *?\= *?\'(.+)\'/s) {
						$prefix2 = $1;
						print STDERR "\r\nPrefix was set as $prefix\r\n\r\n";
						$answer =~ s/\Q$&\E//;
					}
				}
				$answer =~ s/^ +| +$//g;
				$outputtemplate = $answer;
			}
		} else {
			if ($answer =~ / {0,1}\= {0,1}NUM/s) {
				$outkey = 1;
				$answer =~ s/\Q$&\E//;
				if ($answer =~ /PF *?\= *?\'(.+)\'/s) {
					$prefix2 = $1;
					print STDERR "\r\nPrefix was set as $prefix\r\n\r\n";
					$answer =~ s/\Q$&\E//;
				}
			}
			$answer =~ s/^ +| +$//g;
			$outputtemplate = $answer;
		}
	}
	
	$outputtemplate =~ s/[\r\n]//g;
	if (grep { /$opts{fldfmt}/i } @fmtlist) {
		print STDERR "\r\nPreset format was selected and it requires some information\r\n\r\n";
		my @allinfoname = ('Author', 'Article title', 'Journal', 'Year', 'Volume', 'Issue', 'Pages', 'DOI', 'PubMed ID', 'PubMed Central ID', 'Abstract', 'Author information', 'Attribute');
		my @allinfovar = @allinfoname;
		for my $i (@allinfovar) {
			$i = '';
		}
		$refkey = $refkeylist[0];
		@fkeylist = ();
		@fvallist = ();
		$fmtoutput = '';
		@tmpfslist = @fslist;
		$tmpinputt = $inputtemplate;
		fieldsetting();
		$fieldnum = $#fvallist + 1;
		for my $i (0..$#allinfoname) {
			my $answer = '';
			$answer =~ s/[\r\n]//g;
			if ($opts{fldfmt} =~ /raw|unchange/i) {
				last;
			}
			if ($opts{fldfmt} =~ /febs|npg/i && ($i == 5 || $i > 6)) {
				next;
			}
			if ($opts{fldfmt} =~ /lcp|hokudai/i && ($i == 5 || $i > 8)) {
				next;
			}
			if ($opts{fldfmt} !~ /default/i && $i >8) {
				last;
			}
			if ($opts{fldfmt} !~ /abstract/ && $i > 9) {
				last;
			}
			if ($opts{fldfmt} =~ /abstract/ && $i == 11) {
				last;
			}
			print STDERR "First record was separated into the following $fieldnum fields, for example ~~~~~~~~~~\r\n\r\n";
			for my $j (0..$#fvallist) {
				my $curfieldnum = $j +1;
				if ($fvallist[$j]) {
					print STDERR "Field $curfieldnum -> $fvallist[$j]\r\n";
				}
			}
			print STDERR "\r\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
			print STDERR "Input $allinfoname[$i] field\r\n";
			print STDERR " * Number (1-$fieldnum): sets it as $allinfoname[$i] field (prefix is not needed)\r\n";
			print STDERR " * 'S' or 's': skips all the input steps\r\n";
			print STDERR " * 'Q' or 'q': ends program\r\n";
			print STDERR " * Other inputs: use them directly for $allinfoname[$i] field for all the records\r\n\r\n";
			$answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			$answer =~ s/^ +| +$//s;
			if ($answer eq 'Q' || $answer eq 'q') {
				print STDERR "\r\nEnding program\r\n";
				exit;
			}
			if ($answer eq 'S' || $answer eq 's') {
				print STDERR "\r\nSkipping field input\r\n\r\n";
				last;
			}
			if ($answer >= 1 && $answer <= $fieldnum) {
				$allinfovar[$i] = $answer -1;
				print STDERR "$allinfoname[$i] field was set\r\n\r\n";
			} elsif ($answer) {
				$allinfovar[$i] = $answer;
				print STDERR "$allinfoname[$i] field/value was set\r\n\r\n";
			} else {
				$allinfovar[$i] = '';
			}
		}
		if ($opts{order} =~ /num|index/i) {
			print STDERR "Index ordering option was selected\r\n\r\n";
			print STDERR "First record was separated into the following $fieldnum fields, for example ~~~~~~~~~~\r\n\r\n";
			for my $j (0..$#fvallist) {
				my $curfieldnum = $j +1;
				if ($fvallist[$j]) {
					print STDERR "Field $curfieldnum -> $fvallist[$j]\r\n";
				}
			}
			print STDERR "\r\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n\r\n";
			print STDERR "Input the field number for ordering,\r\n   or either 'Q' or 'q' to end program\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'Q' || $answer eq 'q') {
				print STDERR "\r\nEnding program\r\n";
				exit;
			} elsif ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
				print STDERR "\r\nInvalid input\r\n";
				print STDERR "Try again (number to proceed, or any other key to end)\r\n";
				$answer = <STDIN>;
				$answer =~ s/[\r\n]//g;
				if ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
					print STDERR "\r\nInvalid input\r\n";
					print STDERR "Ending program\r\n";
					exit;
				} elsif ($answer =~ /^\d+$/) {
					$answer = $&-1;
					$fieldstoget[0] = $answer;
					print STDERR "\r\nIndex field was set\r\n\r\n";
				}
			} elsif ($answer =~ /^\d+$/) {
				$answer = $&-1;
				$fieldstoget[0] = $answer;
				print STDERR "\r\nIndex field was set\r\n\r\n";
			}
		}
		print STDERR "Input values were all set\r\n";
		print STDERR "Proceeding\r\n\r\n";
		for my $h (@refkeylist) {
			valresetting();
			$refkey = $h;
			$orgrefkey = $refkey;
			$refkey =~ s/^ +| +$//g;
			$tmpinputt = $inputtemplate;
			@tmpfslist = @fslist;
			%fields = ();
			@fkeylist = ();
			@fvallist = ();
			$fmtoutput = '';
			fieldsetting();
			if ($allinfovar[0] >= 0 && $allinfovar[0] <= $#fvallist && $allinfovar[0] ne '') {
				$author = $fvallist[$allinfovar[0]];
			} else {
				$author = $allinfovar[0];
			}
			if ($allinfovar[1] && $allinfovar[1] >= 0 && $allinfovar[1] <= $#fvallist && $allinfovar[1] ne '') {
				$title = $fvallist[$allinfovar[1]];
			} else {
				$title = $allinfovar[1];
			}
			if ($allinfovar[2] && $allinfovar[2] >= 0 && $allinfovar[2] <= $#fvallist && $allinfovar[2] ne '') {
				$journal = $fvallist[$allinfovar[2]];
			} else {
				$journal = $allinfovar[2];
			}
			if ($allinfovar[3] && $allinfovar[3] >= 0 && $allinfovar[3] <= $#fvallist && $allinfovar[3] ne '') {
				$year = $fvallist[$allinfovar[3]];
			} else {
				$year = $allinfovar[3];
			}
			if ($allinfovar[4] && $allinfovar[4] >= 0 && $allinfovar[4] <= $#fvallist && $allinfovar[4] ne '') {
				$volume = $fvallist[$allinfovar[4]];
			} else {
				$volume = $allinfovar[4];
			}
			if ($allinfovar[5] && $allinfovar[5] >= 0 && $allinfovar[5] <= $#fvallist && $allinfovar[5] ne '') {
				$issue = $fvallist[$allinfovar[5]];
			} else {
				$issue = $allinfovar[5];
			}
			if ($allinfovar[6] && $allinfovar[6] >= 0 && $allinfovar[6] <= $#fvallist && $allinfovar[6] ne '') {
				$pages = $fvallist[$allinfovar[6]];
			} else {
				$pages = $allinfovar[6];
			}
			if ($allinfovar[7] && $allinfovar[7] >= 0 && $allinfovar[7] <= $#fvallist && $allinfovar[7] ne '') {
				$doi = $fvallist[$allinfovar[7]];
			} else {
				$doi = $allinfovar[7];
			}
			if ($allinfovar[8] && $allinfovar[8] >= 0 && $allinfovar[8] <= $#fvallist && $allinfovar[8] ne '') {
				$pmid = $fvallist[$allinfovar[8]];
			} else {
				$pmid = $allinfovar[8];
			}
			if ($allinfovar[9] && $allinfovar[9] >= 0 && $allinfovar[9] <= $#fvallist && $allinfovar[9] ne '') {
				$pmcid = $fvallist[$allinfovar[9]];
			} else {
				$pmcid = $allinfovar[9];
			}
			if ($allinfovar[10] && $allinfovar[10] >= 0 && $allinfovar[10] <= $#fvallist && $allinfovar[10] ne '') {
				$abstract = $fvallist[$allinfovar[10]];
			} else {
				$abstract = $allinfovar[10];
			}
			if ($allinfovar[11] && $allinfovar[11] >= 0 && $allinfovar[11] <= $#fvallist && $allinfovar[11] ne '') {
				$institute = $fvallist[$allinfovar[11]];
			} else {
				$institute = $allinfovar[11];
			}
			if ($allinfovar[12] && $allinfovar[12] >= 0 && $allinfovar[12] <= $#fvallist && $allinfovar[12] ne '') {
				$attribute = $fvallist[$allinfovar[12]];
			} else {
				$attribute = $allinfovar[12];
			}
			@authorlist = split(/\,/,$author);
			$firstauthor = $authorlist[0];
			$firstauthor =~ s/^ +| +$//;
			if ($opts{order} =~ /num|index/i) {
				$indexkey = $fvallist[$fieldstoget[0]];
			}
			formatting();
			push (@finalallinfo,$fmtoutput);
		}
	outputting();
	} else {
		$refkey = $refkeylist[0];
		@fkeylist = ();
		@fvallist = ();
		$fmtoutput = '';
		@tmpfslist = @fslist;
		$tmpinputt = $inputtemplate;
		fieldsetting();
		$fieldnum = $#fvallist + 1;
		if ($opts{order} =~ /num|index/i) {
			print STDERR "Index ordering option was selected\r\n";
			print STDERR "First record was separated into the following $fieldnum fields, for example ~~~~~~~~~~\r\n\r\n";
			for my $j (0..$#fvallist) {
				my $curfieldnum = $j +1;
				if ($fvallist[$j]) {
					print STDERR "Field $curfieldnum -> $fvallist[$j]\r\n";
				}
			}
			print STDERR "\r\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
			print STDERR "\r\nInput the field number for ordering (prefix is not needed),\r\n   or either 'Q' or 'q' to end program\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'Q' || $answer eq 'q') {
				print STDERR "\r\nEnding program\r\n";
				exit;
			} elsif ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
				print STDERR "\r\nInvalid input\r\n";
				print STDERR "Try again (number, 'Q' or 'q')\r\n\r\n";
				$answer = <STDIN>;
				$answer =~ s/[\r\n]//g;
				if ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
					print STDERR "\r\nInvalid input\r\n";
					print STDERR "Ending program\r\n";
					exit;
				} elsif  ($answer eq 'Q' || $answer eq 'q') {
					print STDERR "\r\nEnding program\r\n";
					exit;
				} elsif ($answer =~ /^\d+$/) {
					$answer = $&-1;
					$fieldstoget[0] = $answer;
				}
			} elsif ($answer =~ /^\d+$/) {
				$answer = $&-1;
				$fieldstoget[0] = $answer;
			}
		} elsif ($opts{order} =~ /name|author|year/i) {
			print STDERR "Name/year ordering option was selected\r\n\r\n";
			print STDERR "First record was separated into the following $fieldnum fields, for example ~~~~~~~~~~\r\n\r\n";
			for my $j (0..$#fvallist) {
				my $curfieldnum = $j +1;
				if ($fvallist[$j]) {
					print STDERR "Field $curfieldnum -> $fvallist[$j]\r\n";
				}
			}
			print STDERR "\r\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
			print STDERR "\r\nInput the field number containing authors\r\n";
			print STDERR " ! Either 'S' or 's' skips this step, and either 'Q' or 'q' ends program\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'Q' || $answer eq 'q') {
				print STDERR "\r\nEnding program\r\n";
				exit;
			} elsif ($answer eq 'S' || $answer eq 's') {
				print STDERR "\r\nSkipping\r\n";
				$fieldstoget[0] = '';
			} elsif ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
				print STDERR "\r\nInvalid input\r\n";
				print STDERR "Try again (number to proceed; any other key to end program)\r\n";
				$answer = <STDIN>;
				$answer =~ s/[\r\n]//g;
				if ($answer !~ /\d/ || $answer < 1 || $answer > $fieldnum) {
					print STDERR "\r\nInvalid input\r\n";
					print STDERR "Ending program\r\n";
					exit;
				} elsif ($answer =~ /^\d+$/) {
					$answer = $&-1;
					$fieldstoget[0] = $answer;
					print STDERR "\r\nAuthor field was set\r\n\r\n";
				}
			} elsif ($answer =~ /^\d+$/) {
				$answer = $&-1;
				$fieldstoget[0] = $answer;
				print STDERR "\r\nAuthor field was set\r\n\r\n";
			}
			print STDERR "Input the field number containing publication year\r\n";
			print STDERR " ! Either 'S' or 's' skips this step, and either 'Q' or 'q' ends program\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'Q' || $answer eq 'q') {
				print STDERR "\r\nEnding program\r\n";
				exit;
			} elsif ($answer eq 'S' || $answer eq 's') {
				print STDERR "\r\nSkipping\r\n";
				$fieldstoget[1] = '';
			} elsif ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
				print STDERR "\r\nInvalid input\r\n";
				print STDERR "Try again (number to proceed; any other key to end program)\r\n";
				$answer = <STDIN>;
				$answer =~ s/[\r\n]//g;
				if ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
					print STDERR "\r\nInvalid input\r\n";
					print STDERR "Ending program\r\n";
					exit;
				} elsif ($answer =~ /^\d+$/) {
					$answer = $&-1;
					$fieldstoget[1] = $answer;
					print STDERR "\r\nPublication year field was set\r\n\r\n";
				}
			} elsif ($answer =~ /^\d+$/) {
				$answer = $&-1;
				$fieldstoget[1] = $answer;
				print STDERR "\r\nPublication year field was set\r\n\r\n";
			}
			print STDERR "Input the field number containing PubMed ID, if any\r\n";
			print STDERR " ! Either 'S' or 's' skips this step, and either 'Q' or 'q' ends program\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'Q' || $answer eq 'q') {
				print STDERR "\r\nEnding program\r\n";
				exit;
			} elsif ($answer eq 'S' || $answer eq 's') {
				print STDERR "\r\nSkipping\r\n";
				$fieldstoget[2] = '';
			} elsif ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
				print STDERR "\r\nInvalid input\r\n";
				print STDERR "Try again (number to proceed; any other key to end program)\r\n";
				$answer = <STDIN>;
				$answer =~ s/[\r\n]//g;
				if ($answer !~ /\d/ || $answer < 1 || $answer > $fieldnum) {
					print STDERR "\r\nInvalid input\r\n";
					print STDERR "Ending program\r\n";
					exit;
				} elsif ($answer =~ /^\d+$/) {
					$answer = $&-1;
					$fieldstoget[2] = $answer;
					print STDERR "\r\nPubMed ID field was set\r\n\r\n";
				}
			} elsif ($answer =~ /^\d+$/) {
				$answer = $&-1;
				$fieldstoget[2] = $answer;
				print STDERR "\r\nPubMed ID field was set\r\n\r\n";
			}
		} elsif ($opts{order} =~ /pm/i) {
			print STDERR "PubMed ID ordering option was selected\r\n";
			print STDERR "First record was separated into the following $fieldnum fields, for example ~~~~~~~~~~\r\n\r\n";
			for my $j (0..$#fvallist) {
				my $curfieldnum = $j +1;
				if ($fvallist[$j]) {
					print STDERR "Field $curfieldnum -> $fvallist[$j]\r\n";
				}
			}
			print STDERR "\r\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
			print STDERR "Input the field number containing PubMed ID\r\n";
			print STDERR " ! Either 'S' or 's' skips this step, and either 'Q' or 'q' ends program\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'Q' || $answer eq 'q') {
				print STDERR "\r\nEnding program\r\n";
				exit;
			} elsif ($answer eq 'S' || $answer eq 's') {
				print STDERR "Skipping\r\n";
				$fieldstoget[0] = '';
			} elsif ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
				print STDERR "\r\nInvalid input\r\n";
				print STDERR "Try again (number to proceed; any other key to end program)\r\n";
				$answer = <STDIN>;
				$answer =~ s/[\r\n]//g;
				if ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
					print STDERR "\r\nInvalid input\r\n";
					print STDERR "Ending program\r\n";
					exit;
				} elsif ($answer =~ /^\d+$/) {
					$answer = $&-1;
					$fieldstoget[0] = $answer;
				}
			} elsif ($answer =~ /^\d+$/) {
				$answer = $&-1;
				$fieldstoget[0] = $answer;
			}
		} elsif ($opts{order} =~ /title/i) {
			print STDERR "Title ordering option was selected\r\n";
			print STDERR "First record was separated into the following $fieldnum fields, for example ~~~~~~~~~~\r\n\r\n";
			for my $j (0..$#fvallist) {
				my $curfieldnum = $j +1;
				if ($fvallist[$j]) {
					print STDERR "Field $curfieldnum -> $fvallist[$j]\r\n";
				}
			}
			print STDERR "\r\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n";
			print STDERR "Input the field number containing article title\r\n";
			print STDERR " ! Either 'S' or 's' skips this step, and either 'Q' or 'q' ends program\r\n\r\n";
			my $answer = <STDIN>;
			$answer =~ s/[\r\n]//g;
			if ($answer eq 'Q' || $answer eq 'q') {
				print STDERR "\r\nEnding program\r\n";
				exit;
			} elsif ($answer eq 'S' || $answer eq 's') {
				print STDERR "Skipping\r\n";
				$fieldstoget[0] = '';
			} elsif ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
				print STDERR "\r\nInvalid input\r\n";
				print STDERR "Try again (number to proceed; any other key to end program)\r\n";
				$answer = <STDIN>;
				$answer =~ s/[\r\n]//g;
				if ($answer !~ /^\d+$/ || $answer < 1 || $answer > $fieldnum) {
					print STDERR "\r\nInvalid input\r\n";
					print STDERR "Ending program\r\n";
					exit;
				} elsif ($answer =~ /^\d+$/) {
					$answer = $&-1;
					$fieldstoget[0] = $answer;
				}
			} elsif ($answer =~ /^\d+$/) {
				$answer = $&-1;
				$fieldstoget[0] = $answer;
			}
		}
		print STDERR "Proceeding\r\n\r\n";
		for my $h (@refkeylist) {
			$refkey = $h;
			$orgrefkey = $refkey;
			$refkey =~ s/^ +| +$//g;
			valresetting();
			$tmpinputt = $inputtemplate;
			@tmpfslist = @fslist;
			%fields = ();
			@fkeylist = ();
			@fvallist = ();
			$fmtoutput = $outputtemplate;
			fieldsetting();
			if (!$outkey && !$prefix2) {
				for my $j (sort {$b <=> $a} 0..1000) {
					my $ofieldkey = $prefix.$j;
					my $ofieldvalue = $fields{$ofieldkey};
					$fmtoutput =~ s/\Q$ofieldkey\E/$ofieldvalue/g;
				}
			} elsif ($prefix2) {
				for my $j (sort {$b <=> $a} 1..1000) {
					my $ofieldkey = $j-1;
					my $ofieldvalue = $fvallist[$ofieldkey];
					$fmtoutput =~ s/\Q$prefix2\E\Q$j\E/$ofieldvalue/g;
				}
			} else {
				for my $j (sort {$b <=> $a} 1..1000) {
					my $ofieldkey = $j-1;
					my $ofieldvalue = $fvallist[$ofieldkey];
					$fmtoutput =~ s/\Q$prefix\E\Q$j\E/$ofieldvalue/g;
				}
			}
			$fmtoutput =~ s/\r\n$|\n$|\r$//;
			if ($opts{order} =~ /num|index/i) {
				$indexkey = $fvallist[$fieldstoget[0]];
				$fmtout_sval{$fmtoutput} = $indexkey;
			} elsif ($opts{order} =~ /name|author|year/i) {
				if ($fieldstoget[0] ne '') {
					$author = $fvallist[$fieldstoget[0]];
				}
				if ($fieldstoget[1] ne '') {
					$year = $fvallist[$fieldstoget[1]];
				}
				if ($fieldstoget[2] ne '') {
				$pmid = $fvallist[$fieldstoget[2]];
				}
				@authorlist = split(/\,|\;/,$author);
				$firstauthor = $authorlist[0];
				$firstauthor =~ s/^ +| +$//g;
				if ($opts{order} =~ /name|author/i) {
					$fmtout_sval{$fmtoutput} = $firstauthor.','.$year.','.$pmid;
				} elsif ($opts{order} =~ /year/i) {
					$fmtout_sval{$fmtoutput} = $year.','.$firstauthor.','.$pmid;
				}
			} elsif ($opts{order} =~ /pm|title/i) {
				my $value = $fvallist[$fieldstoget[0]];
				$fmtout_sval{$fmtoutput} = $value;
			}
			push (@finalallinfo,$fmtoutput);
		}
	outputting();
	}
	if (!$mstext) {
		print STDERR "Done\r\n\r\nEnding program\r\n";
		exit;
	}
}


#Text correction
if ($mstext) {
	if (!@finalallinfo) {
		print STDERR "Trying to generate references from the manuscript file\r\n\r\n";
	}
	if (!$opts{fldfmt}) {
		$opts{fldfmt} = 'raw';
	}
	my $mstext0 = $mstext;
	my @iptreflist = @finalallinfo;
	my @optreflist;
	@finalallinfo = ();
	my @precitation;
	$mstext = ')]'.$mstext.'[(';
	my @precitation = split (/\).+?\(|\].+?\[/s,$mstext);
	$mstext =~ s/^\)\]//;
	$mstext =~ s/\[\($//;
	my $modcit;
	for my $h (@precitation) {
		if ($h =~ /[A-Za-z][A-Za-z\'\-\?]*.*[12]\d{3}|[12]\d{3}[A-Za-z]{0,1}.*[A-Za-z][A-Za-z\'\-\?]*/) {
			my $citation = $h;
			my $citation0 = $citation;
			$modcit = $citation;
			for (1..100) {
				$modcit =~ s/(\d{4})([a-zA-Z]{1})[\,\;] {0,1}([a-zA-Z]{1})/$1$2,$1$3/;
			}
			my @pretogetpaper = split (/[\;\,]/, $modcit);
			my $curauth;
			my @curauthlist;
			my $curyear;
			my @togetpaper;
			for my $i (@pretogetpaper) {
				$i =~ s/ et al\.{0,1}| and\D+//s;
				$i =~ s/^ +| +$//g;
				if ($i =~ /^([A-Za-z][A-Za-z\'\-\?]*( [A-Za-z][A-Za-z\'\-\?]*){0,3}) *?([12]\d{3}[a-zA-Z]{0,1})$/){
					$curauth = $1;
					$curyear = $3;
					push (@togetpaper, '('.$curauth.'.*?)'.$curyear.'|'.$curyear.'(.*?'.$curauth.')');
					push (@curauthlist,$curauth);
				} elsif ($i =~ /^[A-Za-z][A-Za-z\'\-\?]*( [A-Za-z][A-Za-z\'\-\?]*){0,3}$/){
					$curauth = $i;
					push (@curauthlist,$curauth);
				} elsif ($i =~ /^([12]\d{3}[a-zA-Z]{0,1})$/) {
					$curyear = $1;
					push (@togetpaper, '('.$curauth.'.*?)'.$curyear.'|'.$curyear.'(.*?'.$curauth.')');
				}
			}
			my $answer;
			for my $i (@togetpaper) {
				my $index;
				my $refindex;
				if (!grep {/$i/} @iptreflist) {
					valresetting();
					@finalallinfo =();
					print STDERR "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n\r\n";
					print STDERR "Search key $i cannot be found in references\r\n\r\n";
					if ($mstext0 =~ /[^\.]*?\Q$h\E/s) {
						print STDERR "$&  <-- Around here in the manuscript\r\n\r\n";
					}
					print STDERR "What to do?\r\n\r\n";
					print STDERR " * 'S' or 's': performs PubMed search\r\n";
					print STDERR " * 'Q' or 'q': ends program\r\n";
					print STDERR " * Any other key: ignores this section and proceeds\r\n\r\n";
					my $answer = <STDIN>;
					$answer =~ s/[\r\n]//g;
					if ($answer eq 'Q' || $answer eq 'q') {
						print STDERR "\r\nEnding program\r\n";
						exit;
					} elsif ($answer eq 'S' || $answer eq 's') {
						print STDERR "\r\nInput keywords for PubMed search\r\n\r\n";
						$refkey = <STDIN>;
						$refkeyindex = 1;
						$refkey =~ s/[\r\n]//g;
						if ($refkey =~ /pmid\D*?(\d+)/i){
							$refkey = $1;
						} elsif ($refkey =~ /(pmc\d+)/i) {
							$refkey = $1;
						} elsif ($refkey =~ /doi[\s\.\:\,\;\|\=]+?([\/\.\w\d]+)/i) {
							$refkey = $1;
						} else {
							$refkey =~ s/[^\w\d\s]/\+/g;
							$refkey =~ s/\s/\+/g;
						}
						print STDERR "\r\nSearching PubMed for $refkey\r\n\r\n";
						pmsearching();
						if (@finalallinfo) {
							@finalallinfo = sort {$a cmp $b} @finalallinfo;
							for my $j (0..$#finalallinfo) {
								if (!grep {/\Q$finalallinfo[$j]\E/} @optreflist) {
									push (@optreflist, $finalallinfo[$j]);
									$index = $#optreflist + 1;
									$refindex = '[Ref'.$index.']';
									$modcit =~ s/$i/$refindex$&/;
								} else {
									for my $k (0..$#optreflist) {
										if ($k =~ /\Q$finalallinfo[$j]\E/) {
											$index = $k + 1;
											$refindex = '[Ref'.$index.']';
											$modcit =~ s/$i/$refindex$&/;
											last;
										}
									}
								}
							}
						}
						print STDERR "$modcit\r\n";
						$index = '';
						$refindex = '';
					}
				} else {
					my @tmppaperlist = grep {/$i/} @iptreflist;
					if ($#tmppaperlist == 0 && !grep { /\Q$tmppaperlist[0]\E/ } @optreflist) {
						push (@optreflist, $tmppaperlist[0]);
						$index = $#optreflist+1;
						$refindex = '[Ref'.$index.']';
						$modcit =~ s/$i/$1$refindex/s;
					} elsif ($#tmppaperlist == 0 && grep { /\Q$tmppaperlist[0]\E/ } @optreflist) {
						for my $j (0..$#optreflist){
							if ($optreflist[$j] =~ /\Q$tmppaperlist[0]\E/) {
								$index = $j + 1;
								$refindex = '[Ref'.$index.']';
								$modcit =~ s/$i/$1$refindex/s;
								last;
							}
						}
					} elsif ($#tmppaperlist > 0) {
						print STDERR "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\r\n\r\n";
						for my $j (0..$#tmppaperlist) {
							$index = $j +1;
							print STDERR "$index. $tmppaperlist[$j]\r\n\r\n";
						}
						my $tmppapernum = $#tmppaperlist + 1;
						print STDERR "The above $tmppapernum papers were found in the input reference list\r\nfor the search key $i\r\n\r\n";
						if ($mstext0 =~ /[^\.]*?\Q$h\E/) {
							print STDERR "$&  <-- Around here in the manuscript\r\n\r\n";
						}
						print STDERR "What to do?\r\n";
						print STDERR " * Delimited numbers: format information on correponding papers\r\n";
						print STDERR "     1 3-5: format information on the papers 1, 3, 4 and 5, for example\r\n";
						print STDERR " * 'A' or 'a': uses all of them and proceeds\r\n";
						print STDERR " * 'Q' or 'q': ends program\r\n";
						print STDERR " * Any other key: uses none of them and proceeds\r\n\r\n";
						
						my $answer = <STDIN>;
						$answer =~ s/[\r\n]//g;
						$answer =~ s/^ +| +$//g;
						if ($answer eq 'Q' || $answer eq 'q') {
							print STDERR "\r\nEnding program\r\n";
							exit;
						} elsif ($answer eq 'A' || $answer eq 'a' || $answer =~ /^\d+$/) {
							my @papertogetnum;
							if ($answer eq 'A' || $answer eq 'a') {
								@papertogetnum = (0..$#tmppaperlist);
							} else {
								@papertogetnum = split (/[\s\,\;\:]/,$answer);
								for my $j (@papertogetnum) {
									if ($j =~ /(\d+?)\D+?(\d+?)/) {
										my @seqnum = ($1..$2);
										@papertogetnum = (@papertogetnum,@seqnum);
									}
								}
								@papertogetnum = sort {$a <=> $b} @papertogetnum;
								for my $j (@papertogetnum) {
									$j = $j-1;
								}
							}
							for my $j (@papertogetnum) {
								if (!grep {/\Q$tmppaperlist[$j]\E/} @optreflist) {
									push (@optreflist, $tmppaperlist[$j]);
									$index = $#optreflist + 1;
									$refindex = '[Ref'.$index.']';
									$modcit =~ s/$i/$1$refindex/s;
								} else {
									for my $k (0..$#optreflist) {
										if ($k =~ /\Q$tmppaperlist[$j]\E/) {
											$index = $k + 1;
											$refindex = '[Ref'.$index.']';
											$modcit =~ s/$i/$1$refindex/s;
											last;
										}
									}
								}
							}
						}
					}
				}
			}
			for my $i (@curauthlist) {
				$modcit =~ s/$i.*?\[Ref/[Ref/;
			}
			$modcit =~ s/\]\[/], [/g;
			$modcit =~ s/(\][\,\;])(\[)/$1 $2/g;
			$modcit =~ s/  / /g;
			$modcit =~ s/  / /g;
			$mstext =~ s/([\(\[])\Q$citation\E([\)\]])/$1$modcit$2/;
			$mstext0 =~ s/([\(\[])\Q$citation\E([\)\]])/$1$modcit$2/;
			if ($opts{fldfmt} =~ /febs/i || $opts{fldfmt} =~ /npg/i) {
				$mstext =~ s/[\(\[] *?\[/[/g;
				$mstext =~ s/\] *?[\)\]]/]/g;
				my $modmodcit = $modcit;
				my @seqref;
				for (1..100) {
					if ($modmodcit =~ /\[Ref\d+\]([\,\;] \[Ref\d+\]){1,}/) {
						push (@seqref, $&);
						$modmodcit =~ s/$&//;
					}
				}
				for my $i (@seqref) {
					my $modseqref = $i;
					$modseqref =~ s/\[|\]|Ref| //g;
					my @refnum = split (/[\,\;]/, $modseqref);
					@refnum = sort {$a <=> $b} @refnum;
					if ($opts{fldfmt} =~ /febs/i) {
						my $curfstnum = $refnum[0];
						my $curlastnum = $refnum[0];
						my @modrefnum;
						for my $j (1..$#refnum) {
							if ($refnum[$j] == $curlastnum + 1) {
								$curlastnum = $refnum[$j];
							} elsif ($refnum[$j] > $curlastnum + 1 && $curlastnum - $curfstnum >= 2) {
								$modseqref = $curfstnum.'-'.$curlastnum;
								push (@modrefnum, $modseqref);
								$curfstnum = $refnum[$j];
								$curlastnum = $refnum[$j];
							} elsif ($refnum[$j] > $curlastnum + 1 && $curlastnum - $curfstnum == 1) {
								push (@modrefnum, $curfstnum);
								push (@modrefnum, $curlastnum);
								$curfstnum = $refnum[$j];
								$curlastnum = $refnum[$j];
							} elsif ($refnum[$j] > $curlastnum + 1 && $curlastnum == $curfstnum) {
								push (@modrefnum, $curfstnum);
								$curfstnum = $refnum[$j];
								$curlastnum = $refnum[$j];
							}
						}
						if ($curfstnum == $curlastnum) {
							push (@modrefnum,$curfstnum);
						} elsif ($curfstnum == $curlastnum - 1) {
							push (@modrefnum,$curfstnum);
							push (@modrefnum,$curlastnum);
						} elsif ($curlastnum - $curfstnum >= 2) {
							$modseqref = $curfstnum.'-'.$curlastnum;
							push (@modrefnum, $modseqref);
						}
						$modseqref = join (',',@modrefnum);
						$modseqref = '['.$modseqref.']';
					} elsif ($opts{fldfmt} =~ /npg/i) {
						$modseqref = join (',',@refnum);
						$modseqref = '<sup>'.$modseqref.'</sup>';
					}
					$mstext =~ s/\Q$i\E/$modseqref/;
				}
			}
		}
	}
	if ($opts{fldfmt} =~ /febs/i) {
		$mstext =~ s/\[Ref(\d+)\]/[$1]/g;
	} elsif ($opts{fldfmt} =~ /npg/i) {
		$mstext =~ s/ \[Ref(\d+)\]/<sup>$1<\/sup>/g;
	}
	my $mstext1 = $mstext;
	$mstext = 0;
	print STDERR "Done\r\nOutputting references\r\n\r\n";
	@finalallinfo = @optreflist;
	outputting();
	for my $i (@optreflist) {
		if (!grep { /\Q$i\E/ } @iptreflist ) {
			print STDERR "\r\n! Output reference list contains a paper absent in the input reference list\r\n\r\n";
			last;
		}
	}
	print STDERR "References can be ordered by first authors' names as well\r\nDo it? -- 'Y' or 'y' to do it; Any other key to skip it\r\n\r\n";
	my $answer = <STDIN>;
	$answer =~ s/[\r\n]//g;
	if ($answer eq 'Y' || $answer eq 'y') {
		$opts{order} = 'namesave';
		print STDERR "\r\nOK. Input a file name to save the output\r\n\r\n";
		my $outrefname = <STDIN>;
		$outrefname =~ s/[\r\n]//g;
		open (RFO, "> $outrefname");
		outputting();
		close (RFO);
		print STDERR "\r\nOK. Done\r\n";
	}
	print STDERR "\r\nWhat to do about the manuscript file with sequential reference numbers?\r\n";
	print STDERR " * 'Q' or 'q': ends program without saving it\r\n";
	print STDERR " * 'M' or 'm': replaces the reference numbers in the text\r\n   with first author names and years\r\n";
	print STDERR " * 'S' or 's': saves the file with a designated file name\r\n   (input will be required)\r\n";
	print STDERR " * Any other key: saves the file\r\n   ('.refsorted.txt' is added to the original file name)\r\n   and ends program\r\n\r\n";
	my $outmsname;
	my $answer = <STDIN>;
	$answer =~ s/[\r\n]//g;
	if ($answer eq 'M' || $answer eq 'm') {
		print STDERR "\r\nModifying the manuscript\r\n\r\n";
		$mstext = 1;
		for my $i (0..$#finalallinfo) {
			my $index = $i + 1;
			my $refindex = '[Ref'.$index.']';
			my $correctkey = $fmtout_sval{$finalallinfo[$i]};
			$correctkey =~ s/^ +| +$//g;
			$correctkey =~ s/ [A-Z]+//g;
			$correctkey =~ s/\,/ et al., /;
			$mstext0 =~ s/\Q$refindex\E/$correctkey/g;
		}
		$mstext0 =~ s/\,(\S)/, $1/g;
		$mstext0 =~ s/ +([\)\]])/$1/g;
		print STDERR "Done\r\nInput a manuscript file name for outputting\r\n\r\n";
		my $outmsname0 = <STDIN>;
		open (MSO, "> $outmsname0");
		print MSO "$mstext0\r\n";
		close (MSO);
		print STDERR "Done\r\nSave the manuscript file with sequential reference numbers as well?\r\n";
		print STDERR " * 'Q' or 'q': ends program without saving it\r\n";
		print STDERR " * 'S' or 's': saves the file with a designated file name\r\n   (input will be required)\r\n";
		print STDERR " * Any other key: saves the file\r\n   ('.refsorted.txt' is added to the original file name)\r\n   and ends program\r\n\r\n";
		$answer = <STDIN>;
		$answer =~ s/[\r\n]//g;
	}
	if ($answer eq 'Q' || $answer eq 'q' ) {
		print STDERR "\r\nEnding program\r\n";
		exit;
	} elsif ($answer eq 'S' || $answer eq 's') {
		print STDERR "\r\nInput a manuscript file name for output\r\n\r\n";
		$outmsname = <STDIN>;
		$answer =~ s/[\r\n]//g;
	} else {
		$outmsname = $opts{order}.'.refsorted.txt';
	}
	open (MSO, "> $outmsname");
	print MSO "$mstext1\r\n";
	close (MSO);
	print STDERR "\r\nOK. Done\r\n\r\nEnding program\r\n";
	exit;
}


exit;

