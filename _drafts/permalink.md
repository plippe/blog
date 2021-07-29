# Permalink, accuracy above all
The web is one big mess of documents. Those are less and less static. This makes our experiences unique compared to other visitors. There are many reasons to update the content of a web page, but linking to a specific version makes sense too.

To start, I describe how a social platform, like Reddit, can use a payload in the URL to display messages in a consistent manner. I continue with a store, like Amazon, where the use of a signature would simplify advertising. Finally, I share a few snippets to reproduce these ideas.

## Payload
Web pages are fetched with HTTP requests. Those are built with an address, a method, and various other bits. Clicking a link is the same as executing a GET request on the relevant URL with the cookies found in the browser.

In most cases, a server extracts interesting information from the request. This allows it to build the requested page.

Sharing a link doesn't guarantee the same experience. Putting cookies aside, for now, an obvious reason is time. As time passes, the server could have a different response. This is true for most websites, but especially on social platforms. Users create, update, and delete content in a matter of seconds.

To capture a moment in time, users could take a screenshot, or download the web pages. Both solutions aren't practical. The best way is to enrich the URL with more information.

## Signature

forgery related to the cookies. Authenticated users receive personalized experiences compared to anonymous visitors. This will be information. Based on that description, sharing a link doesn't guarantee consistency. The obvious session related information is one reason, but isn't the only. A user wouldn't its account a link, linkOther useful details, like session identification, isn't in the URL, and will be ignored for now.


Client heavy websites use SOAP, ReST, or a variation of those, to build a document for users.
built around links. Documents display some information, and refer to other documents. been around for a good whileAdvertising online is a tricky business. 
Platform exists, but need to follow their requirements.
The main goal is user satisfaction with accurate advertisements.
Product information is submitted, and content after link must match. Price is by far the most important. 
Price has different requirements based on country where advertised. Currency, taxes, shipping, sales, all those criterias can change. Simple solution is to add them to the URL.
JSON in URL
Encoding to make the URL user friendly
Sign the URL to avoid manipulation. Validate in the backend.
Expire the content to allow price variation
