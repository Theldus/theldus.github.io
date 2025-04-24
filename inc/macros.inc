;
; Theldus's blog
; This is free and unencumbered software released into the public domain.
;

%include "config.inc"

%ifndef IS_POST
%define IS_POST 0
%endif

%ifndef PAGE_TITLE_STR
%define PAGE_TITLE_STR BLOG_TITLE
%endif

; Basic post structure
%macro  SET_POST_TITLE 1
%define POST_TITLE_STR %1
%define PAGE_TITLE_STR %1
%ifdef POST_DATE_CREATED
	%define IS_POST 1
%endif
%endmacro

%macro SET_POST_DATES 2
%define POST_DATE_CREATED  %1
%define POST_DATE_MODIFIED %2
%ifdef POST_TITLE_STR
	%define IS_POST 1
%endif
%endmacro

; Set post discussion/issue number/whatever you use to
; identify your post on your Git platform
%macro SET_POST_DNBR 1
%define POST_DISCUSSION_NR %1
%endmacro

; Text formatting
%define MACRO_PERCENT   %
%define MACRO_HASH      #
%define MACRO_SEMIC     ;
%define B(text+)        <b>text</b>
%define BBB(text+)      <b>text</b>
%define I(text+)        <em>text</em>
%define U(text+)        <u>text</u>
%define LINK(url, text) <a href=url>text</a>

; Paragraphs
%define PS <p>
%define PE </p>

; Headings

; Convert a title to an anchor tag
%macro caption_to_link 1+
	%defstr input_str %1
	%assign i          1  ; Counter
	%strlen len input_str ; String length
	%defstr out_str       ; Output string  TODO: this name should be changed!!!
	%rep len
		%substr ch input_str i
		%if ch >= 'A' && ch <= 'Z'
			%substr ch 'abcdefghijklmnopqrstuvwxyz' ch+32-96
			%strcat out_str out_str, ch
		%elif (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')
			%strcat out_str out_str, ch
		%elif (ch == ' ')
			%strcat out_str out_str, '-'
		%elif (ch == '-')
			%strcat out_str out_str, ch
		%endif
		%assign i i+1
	%endrep
	%undef i
	%undef len
	%undef input_str
%endmacro

; First level
%macro S 1+
caption_to_link %1
%defstr hash #
%strcat hash hash,out_str
<h2 id=out_str>
    <a href=hash class="heading-link">%1</a>
</h2>
%endmacro

; Second level
%macro SS 1+
caption_to_link %1
%defstr hash #
%strcat hash hash,out_str
<h3 id=out_str>
    <a href=hash class="heading-link">%1</a>
</h3>
%endmacro

; Third level
%macro SSS 1+
caption_to_link %1
%defstr hash #
%strcat hash hash,out_str
<h4 id=out_str>
    <a href=hash class="heading-link">%1</a>
</h4>
%endmacro

; Fourth level
%macro SSSS 1+
caption_to_link %1
%defstr hash #
%strcat hash hash,out_str
<h5 id=out_str>
    <a href=hash class="heading-link">%1</a>
</h5>
%endmacro

;
; Images with captions
; Parameters:
;   %1 = path/link to the image
;   %2 = image description
;
%ifndef IMG_COUNT
%assign IMG_COUNT 0
%endif

%macro  IMG 2+
<a href=%1 target="_blank">
	<img src=%1 alt=%2 />
</a>
%assign IMG_COUNT IMG_COUNT+1
<p class="caption">Image IMG_COUNT: %2</p>
%endmacro

;
; Images with captions
; Parameters:
;   %1 = size in percentage (0-100)
;   %1 = path/link to the image
;   %2 = image description
;
%macro  IMG_S 3+
%defstr stri width:
%defstr perc %2
%strcat stri stri perc
%strcat stri stri '%;'
<a href=%1 target="_blank">
	<img src=%1 alt=%3 style=stri/>
</a>
%assign IMG_COUNT IMG_COUNT+1
<p class="caption">Image IMG_COUNT: %3</p>
%undef stri
%undef perc
%endmacro

;
; Images with captions
; Parameters:
;   %1 = path/link to the image src
;   %2 = image description
;   %3 = alternative link
;
%macro IMG_L 3
<a href=%3 target="_blank">
	<img src=%1 alt=%2 />
</a>
%assign IMG_COUNT IMG_COUNT+1
<p class="caption">Image IMG_COUNT: %2</p>
%endmacro


; Code blocks
%define BC_S <pre>
%define BC_E </pre>
%define BC_E_CAPTION(caption) \
	</pre> \
	<p class="caption"><a href=GIT_SITE_REPO/blob/master/caption>File: caption</a></p>

%define BC(src_code+) <code>src_code</code>

; Lists
%define UL_CSS(css) <ul class=css>
%define UL_S <ul>
%define UL_E </ul>
%define OL_S <ol>
%define OL_E </ol>
%define LI_S <li>
%define LI_E </li>

; Special paragraph types
%define PS_N <p class="note">💡 Note:
%define PS_W <p class="warning">⚠️ Warning:
%define PS_I <p class="info">ℹ️ Info:

; Tables
%define TABLE_S <table>
%define TABLE_E </table>
%define TR_S <tr>
%define TR_E </tr>
%define TH(text) <th>text</th>
%define TD(text) <td>text</td>

; Table Row Macros (for easy table creation)
%define TT1(col1) TR_S TH(col1) TR_E
%define TT2(col1, col2) TR_S TH(col1) TH(col2) TR_E
%define TT3(col1, col2, col3) TR_S TH(col1) TH(col2) TH(col3) TR_E
%define TT4(col1, col2, col3, col4) TR_S TH(col1) TH(col2) TH(col3) TH(col4) TR_E

%define TL1(col1) TR_S TD(col1) TR_E
%define TL2(col1, col2) TR_S TD(col1) TD(col2) TR_E
%define TL3(col1, col2, col3) TR_S TD(col1) TD(col2) TD(col3) TR_E
%define TL4(col1, col2, col3, col4) TR_S TD(col1) TD(col2) TD(col3) TD(col4) TR_E

; Footer and license
%define LICENSE(url, text) \
	<p class="license">This post is licensed under <a href=url>text</a> by the author.</p>
