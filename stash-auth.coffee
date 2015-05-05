
qs = require "querystring"
{join} = require "path"
{OAuth} = require "oauth"

handleError = (err, next)->
	# https://github.com/ciaranj/node-oauth/issues/250
	if typeof err is "object" and not (err instanceof Error)
		error = new Error JSON.stringify err
		error[k] = v for k, v of err
		try error[k] = v for k, v of qs.parse err.data
		next error
	else
		next err

module.exports = class StashAuth
	constructor: (
		@API_URL
		CONSUMER_KEY
		privateKeyData
		fullCallbackURL
	)->
		@requestTokenURL = "#{@API_URL}/plugins/servlet/oauth/request-token"
		@accessTokenURL = "#{@API_URL}/plugins/servlet/oauth/access-token"
		@userAuthorizationURL = "#{@API_URL}/plugins/servlet/oauth/authorize"
		
		@consumer =
			new OAuth(
				@requestTokenURL
				@accessTokenURL
				CONSUMER_KEY
				""
				"1.0"
				fullCallbackURL
				"RSA-SHA1"
				null
				privateKeyData
			)

	auth: (req, res, next)=>
		
		req.session.stashAuthReturnURL = req.originalUrl
		if req.session.oauthAccessToken
			
			req.stash = {}
			for method in ["get", "put", "delete"]
				do (method)=>
					req.stash[method] = (url, callback)=>
						@consumer[method] "#{@API_URL}/rest/#{url}",
							req.session.oauthAccessToken
							req.session.oauthAccessTokenSecret
							"application/json"
							(err, data)=>
								return callback err if err
								try data = JSON.parse data catch err
								callback err, data
			
			next()
		else
			@consumer.getOAuthRequestToken (err, oauthToken, oauthTokenSecret, results)=>
				return handleError err, next if err
				req.session.oauthRequestToken = oauthToken
				req.session.oauthRequestTokenSecret = oauthTokenSecret
				res.redirect "#{@userAuthorizationURL}?oauth_token=#{oauthToken}"
	
	authCallback: (req, res, next)=>
		@consumer.getOAuthAccessToken(
			req.session.oauthRequestToken
			req.session.oauthRequestTokenSecret
			req.query.oauth_verifier,
			(err, oauthAccessToken, oauthAccessTokenSecret, results)=>
				return handleError err, next if err
				req.session.oauthAccessToken = oauthAccessToken
				req.session.oauthAccessTokenSecret = oauthAccessTokenSecret
				res.redirect req.session.stashAuthReturnURL
		)
