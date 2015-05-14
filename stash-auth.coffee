
qs = require "querystring"
{join} = require "path"
{OAuth} = require "oauth"

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
			
			method = (url, params, callback)=>
				if typeof arguments[1] is "function"
					[params, callback] = [{}, arguments[1]]
				
				if m = url.match /(.*)?(.+=)/
					more_params = params
					params = qs.parse m[2]
					params[k] = v for k, v of more_params
					url = m[1]
				
				if Object.keys(params).length > 0
					url = "#{url}?#{qs.stringify params}"
				
				unless url.match /^https?:\/\//
					url = "#{@API_URL}/rest/#{url}"
				
				[
					url
					params
					(err, data)=>
						return handleOAuthError err, callback if err
						unless typeof data is "object"
							try data = JSON.parse data catch json_err
						callback json_err, data
					req.session.oauthAccessToken
					req.session.oauthAccessTokenSecret
				]
			
			req.stash =
				get: (url, params, callback)=>
					[url, params, callback, access, access_secret] = method url, params, callback
					@consumer.get url,
						access, access_secret
						"application/json"
						callback
				# post: (url, params, callback)=>
				# 	[url, params, callback] = method url, params, callback
				# 	@consumer.post url,
				# 		access, access_secret
				# 		body, content_type
				# 		callback
				# put: (url, params, callback)=>
				# 	[url, params, callback] = method url, params, callback
				# 	@consumer.put url,
				# 		access, access_secret
				# 		body, content_type
				# 		callback
				delete: (url, params, callback)=>
					[url, params, callback, access, access_secret] = method url, params, callback
					@consumer.delete url,
						access, access_secret
						callback
				getAll: (url, params, callback)=>
					[url, params, callback] = method url, params, callback
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
