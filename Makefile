HUGO_DESTINATION := public

release:
	rm -fr ${HUGO_DESTINATION}

	hugo \
		--baseURL 'https://plippe.github.io/blog/' \
		--destination ${HUGO_DESTINATION}

	cd ${HUGO_DESTINATION} && \
		git init && \
		git remote add origin git@github.com:plippe/blog.git && \
		git checkout -b gh-pages && \
		git add . && \
		git commit --allow-empty-message --message '' && \
		git push -f origin gh-pages
