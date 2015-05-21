
# Stash Auth

Middleware helper
to authorize with [Stash](https://www.atlassian.com/software/stash) (via OAuth)
and easily access [Stash's REST APIs](https://developer.atlassian.com/stash/docs/latest/reference/rest-api.html)


## Install

`npm i stash-auth --save`


## Use

```js
var StashAuth = require("stash-auth");

var stash = new StashAuth(
	STASH_API_URL, // e.g. http://localhost:7990/stash
	STASH_CONSUMER_KEY, // can be anything, as long as it's the same as in Stash
	PRIVATE_KEY_DATA, // fs.readFileSync("server.key", "utf8")
	STASH_CALLBACK_FULL_URL // full, remote-accessable url (including protocol, host and path) to the auth callback route on this server
);

app.use("/stash/auth-callback", stash.authCallback);
```

The `stash.auth` middleware will authorize with Stash
before redirecting back to the original URL
(through the auth callback route)
If a user is already authorized,
it invokes the next middleware,
where you have access to `req.stash`

```js
app.use("/commits/:project/:repo/", stash.auth, function (req, res, next) {
	var project = req.params.project;
	var repo = req.params.repo;
	var api_url = "api/1.0/projects/" + project + "/repos/" + repo + "/commits";
	req.stash.get(api_url, function (err, data) {
		if (err) {
			next(err);
		} else {
			res.send(data);
		}
	});
});
```

There are methods on `req.stash`
corresponding to HTTP methods
supported by [1j01/node-oauth](https://github.com/1j01/node-oauth):
`get`, `post`, `put` and `delete`.

Each method takes the following parameters:

- **url**: `String`, under `/rest/`
- **params**: _optional_ `Object`, added as a query string to the URL
- **callback**: `function(err, items){ ... }`

Additionally there is a `getAll` method,
which will try to fetch every item from every page
in a [paged](https://developer.atlassian.com/static/rest/stash/3.8.0/stash-rest.html#paging-params) API.
This method isn't particularly recommended,
as it circumvents not just the pagination,
but the purpose of the pagination.
