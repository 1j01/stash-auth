
# Stash Auth

Middleware helper
to authorize with [Stash](https://www.atlassian.com/software/stash) (via OAuth)
and easily access Stash's [REST APIs](https://developer.atlassian.com/stash/docs/latest/reference/rest-api.html)


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

// The stash.auth middleware will authorize with Stash before
// redirecting back to the original URL (through the auth callback route)
// If a user is already authorized, it invokes the next middleware,
// where you have access to req.stash.get|put|delete(api_url, callback)
app.use("/commits/:project/:repo/", stash.auth, function (req, res) {
	var project = req.params.project;
	var repo = req.params.repo;
	var api_url = "api/1.0/projects/" + project + "/repos/" + repo + "/commits";
	req.stash.get(api_url, function (err, data) {
		if (err) {
			res.send(err);
		} else {
			res.send(data);
		}
	});
});
```
