require 'goliath'

## Is this the best way to require another sub-system/gem in the same global project folder?
require File.expand_path('../../../common/lib/common', __FILE__)
##

$:.unshift File.expand_path('../../lib', __FILE__)

require 'image/version'
require 'image/meta'
require 'image/cli'
require 'image/store/s3'
require 'image/store/cumulus'
require 'image/store/walrus'
require 'image/store/lunacloud'
require 'image/store/hdfs'
require 'image/store/http'
require 'image/store/file_system'
require 'image/store/store'
require 'image/routes/head_image'
require 'image/routes/get_images'
require 'image/routes/get_images_detail'
require 'image/routes/get_image'
require 'image/routes/post_image'
require 'image/routes/put_image'
require 'image/routes/delete_image'
require 'image/routes/delete_all_images'
require 'image/server'
require 'image/client'



