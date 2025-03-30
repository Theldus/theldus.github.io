;
; Theldus's blog
; This is free and unencumbered software released into the public domain.
;

<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="UTF-8" />
		<meta name="viewport" content="width=device-width, initial-scale=1.0" />
		<title>PAGE_TITLE_STR</title>
		<link rel="icon" type="image/x-icon" href="/assets/img/favicons/favicon.ico">
		<link rel="stylesheet" href="/assets/styles.css">
	</head>
	<body>
		<div class="sidebar">
			<a href="/">Home</a>
			<a href="/about">About</a>
			<a href=GIT_ACCOUNT>GitHub</a>
			%ifdef POST_DISCUSSION_NR
			<a href=GIT_DISC_LINK/POST_DISCUSSION_NR>Post Comments</a>
			%endif
		</div>
		<div class="container">
			<h1 class="blog-title"><a href="/">BLOG_TITLE</a></h1>
			<article>
			%if IS_POST
				<h1>POST_TITLE_STR</h1>
				<p class="meta">By POST_AUTHOR | Published: POST_DATE_CREATED | Last Modified: POST_DATE_MODIFIED</p>
			%endif
