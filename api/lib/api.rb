require 'goliath'

## Is this the best way to require another sub-system/gem in the same global project folder?
require File.expand_path('../../../common/lib/common', __FILE__)
##

$:.unshift File.expand_path('../../lib', __FILE__)

require 'api/version'
require 'api/meta'
require 'api/cli'
require 'api/store/file_system'
require 'api/store/http'
require 'api/store/s3'
require 'api/store/store'
require 'api/routes/head_image'
require 'api/routes/get_images'
require 'api/routes/get_images_detail'
require 'api/routes/get_image'
require 'api/routes/post_image'
require 'api/routes/put_image'
require 'api/routes/delete_image'
require 'api/routes/delete_all_images'
require 'api/server'
require 'api/client'



