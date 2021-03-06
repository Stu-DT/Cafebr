---
title: 'Cafebr: Citation Amender/Formatter for Biological Research'
tags:
  - Perl
  - HTML/JavaScript
  - Biology
  - PubMed
  - Manuscript
  - Reference management
authors:
 - name: Daisuke Tsugama
   orcid: 0000-0002-4946-678X
   affiliation: "1"
affiliations:
 - name: Research Faculty of Agriculture, Hokkaido University
   index: 1
date: 23 August 2018
bibliography: paper.bib
---


# Summary

A reference list is an essential part of a manuscript for an academic article. Generating a reference list consists of three steps: (1) Finding and/or collecting appropriate articles to cite, (2) extracting necessary pieces of information from them, and (3) outputting these pieces of information in a style specific to a journal to which the manuscript is submitted. The steps 2 and 3 are error-prone if manually performed. To perform these steps with less errors, reference management software packages have been developed. EndNote [@EndNote] is an example of such packages. It allows users to search for articles of interest, to deposit them in a database, and to output information about selected articles in a style chosen from more than 2000 preset styles. However, it is a commercial, non-free program, and incompatible with Linux operating systems. Zotero [@Zotero] and Mendeley [@Mendeley] are examples of popular free reference manager packages that can implement the functions similar to those of EndNote, and can run on many platforms such as Windows, Mac OS X, and Linux. All of these programs have many functions and user-friendly interfaces, and have still been improving. However, such multifunctionality seems to have been counteracting with simplicity: It requires many clicks to obtain a final output, and even making small changes in the output requires users to look into and edit a file outside a main execution file. In reality, it is often necessary to reformat a formatted reference list (for example, when a manuscript is declined by a journal and it is submitted to another journal), but such reformatting with the above packages is also not very simple. Here, the author introduces Cafebr (Citation Amender/Formatter for Biological Research), which was developed to simplify the process of generating a reference list. Cafebr was originally written in Perl, and has been converted to a GUI version, cafebr.html, using HTML and JavaScript. As such, it can run on web browsers (at least Firefox, Chrome, and Microsoft Edge) in any platforms.

To achieve the above step 1 (i.e., for articles), Cafebr can search the MEDLINE database with the PubMed search engine [@PubMed], which covers articles with a wide variety of biology fields and is therefore most commonly used for biological research. Cafebr then extracts pieces of informaiton on articles from search results, and displays them in a table for selecting articles for further processing, achieving the above step 2. It is also possible for Cafebr to extract such pieces of information from texts provided by users. Extracted pieces of information should be precise if the provided texts are in the PubMed XML format, the PubMed abstract (text) format, or the Cafebr database format, in which one line corresponds to one article record consisting of 12 tab-delimited data fields (Authors, Article Title, Publication Year, Journal name, Volume, Issue, Pages, PubMed ID (PMID), PubMed Central ID (PMCID), DOI, Attributes, Author Information (affiliation etc.)). Information can be extracted even from texts in none of these formats if delimiters are provided on Cafebr. For example, the reference "Tsugama D (2018) Cafebr development." can be delimited by the three fields "Tsugama D", "2018" and "Cafebr development" if the delimiting pattern "F1 (F2) F3." is provided. In this "Delimiter" option, it is also possible to use a journal name as a delimiter if the journal name is availeble in PubMed. All journal names are listed in the cafebr.html file itself. The journal names are major contributers to the large (~2-MB) file size of cafebr.html, but allows it to be stand-alone.

The extracted pieces of information are organized to generate a final list, achieving the above steps 2 and 3. For this, a template for field arrangement and an order of references can be designated. Some of the preset templates add HTML tags to specific fields to display them in the italic, bold, or superscript style on a web browser. Microsoft Word, which would be usually used for the final manual formatting of a manuscript, can maintain such a style if such words are copied and pasted with the "Match Destination Formatting" option. The number of preset templates for field arrangement is only five thus far (will be increased in the future). However, it is possible to edit them directly on the interface of Cafebr, and to get flexible results. As an ordering option, "As in manuscript" is available. This option outputs references as they are cited in the manuscript, and converts citations such as "(Tsugama et al., 2018)", "(Mike et al., 2014)" to "[Ref1]", "[Ref2]". All of these functions except the PubMed search can be locally executed with the single file cafebr.html. Its online version can execute all of the functions with the aid of a CGI program (cafebr.cgi), and is available at either http://stdtgm.itigo.jp/cafebr/cafebr.html [@cbonline_main] or http://studtsugama.s1006.xrea.com/cafebr/cafebr.xhtm [@cbonline_backup].

### Figure 1. Example of use of the PubMed searching option.
![Example of use of the PubMed searching option.](PM_search.PNG)

### Figure 2. Example of use of the Delimiter searching option.
![Example of use of the Delimiter searching option.](Delimiter.PNG)

# References
