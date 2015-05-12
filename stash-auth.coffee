
qs = require "querystring"
{join} = require "path"
{OAuth} = require "oauth"
{METHODS} = require "http"

handleOAuthError = (err, next)->
	# https://github.com/ciaranj/node-oauth/issues/250
	if typeof err is "object" and not (err instanceof Error)
		data = {}
		try data[k] = v for k, v of qs.parse err.data
		msg_json = {}
		msg_json[k] = v for k, v of data when k isnt "oauth_signature" and k isnt "oauth_signature_base_string"
		error = new Error "Stash OAuth HTTP status code #{err.statusCode}: #{JSON.stringify msg_json}"
		error[k] = v for k, v of data
		error[k] = v for k, v of err
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
			for method in METHODS
				do (method)=>
					method = method.toLowerCase()
					req.stash[method] = (url, params, callback)=>
						if typeof params is "function"
							[params, callback] = [{}, params]
						if m = url.match /(.*)?(.+=)/
							more_params = params
							params = qs.parse m[2]
							params[k] = v for k, v of more_params
							url = m[1]
						if Object.keys(params).length > 0
							url = "#{url}?#{qs.stringify params}"
						@consumer[method] "#{@API_URL}/rest/#{url}",
							req.session.oauthAccessToken
							req.session.oauthAccessTokenSecret
							"application/json"
							(err, data)=>
								return callback err if err
								try data = JSON.parse data catch err
								callback err, data
			
			req.stash.getAll = (url, params, callback)=>
				if typeof params is "function"
					[params, callback] = [{}, params]
				values = []
				start = 0
				do getSome = (start)=>
					params.start = start
					req.stash.get url, params, (err, data)=>
						return callback err if err
						values = values.concat data.values
						if data.isLastPage
							callback null, values
						else
							getSome data.nextPageStart
			
			next()
		else
			@consumer.getOAuthRequestToken (err, oauthToken, oauthTokenSecret, results)=>
				return handleOAuthError err, next if err
				req.session.oauthRequestToken = oauthToken
				req.session.oauthRequestTokenSecret = oauthTokenSecret
				res.redirect "#{@userAuthorizationURL}?oauth_token=#{oauthToken}"
	
	authCallback: (req, res, next)=>
		@consumer.getOAuthAccessToken(
			req.session.oauthRequestToken
			req.session.oauthRequestTokenSecret
			req.query.oauth_verifier,
			(err, oauthAccessToken, oauthAccessTokenSecret, results)=>
				return handleOAuthError err, next if err
				req.session.oauthAccessToken = oauthAccessToken
				req.session.oauthAccessTokenSecret = oauthAccessTokenSecret
				res.redirect req.session.stashAuthReturnURL
		)
