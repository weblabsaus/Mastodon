# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << 'node_modules'

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
<<<<<<< HEAD
# Rails.application.config.assets.precompile += %w()
=======
Rails.application.config.assets.precompile += %w(application_public.js custom.css
                                                 on_submit_new_user.js)
>>>>>>> 93b77575d1bc0a6762236475b13365b5b888ab1a

Rails.application.config.assets.initialize_on_precompile = true
