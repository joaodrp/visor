require 'em-synchrony'
require 'em-synchrony/em-mongo'
require 'json'

# Establishes and returns the MongoDB database connection
# If no collection is provided (nil) it returns a database object
#
# @param coll [String] the wanted collection or nil for no collection
# @param host [String] the host address
# @param db [String] the wanted database
#
# TODO: assemble db and collections if not already exisiting
  # db.counters.insert({_id:"id", count:1})
  # var o = db.counters.findAndModify({query: {_id: "id"}, update: {$inc: {count: 1}}});
  # db.images.save({_id:o.count, ...})
def configure_db(coll, host='localhost', db='cbolt')
  if coll.nil?
    EM::Mongo::Connection.new(host).db(db)
  else
    EM::Mongo::Connection.new(host).db(db).collection(coll)
  end
end

def validate_data(meta)

end

# Returns an array with the public images metadata
# If no public image is found it returns an empty array.
#
# @return [Array] the public images metadata
#
def get_public_images
  images = configure_db('images')
  images.find({access: 'public'}, {order: '_id'})
end

# Returns an array with the requested image's metadata
# If no image is found it returns an empty array.
#
# @param id [Integer] the requested image's id
# @return [Array] the requested image's metadata
#
def get_image(id)
  images = configure_db('images')
  images.find({_id: id})
end

# Delete an image record
#
# @param id [Integer] the image's id to remove
# @return [Array] the deleted image's metadata or empty if image not found
#
def delete_image(id)
  images = configure_db('images')
  res = images.find({_id: id})
  images.remove({_id: id}) unless res.empty?
  res
end

# Create a new image record for the given metadata
#
# @param meta [Hash] the image's metadata
# @return [Integer] the created image id or nil if validation fails
#
def post_image(meta)
  # validate data and connect to db
  validate_data(meta) #TODO: Image data validation
  db = configure_db(nil)
  # atomically generate a new sequential _id overriding the default OID
  counters = db.collection('counters')
  counters.find_and_modify(query: {_id: 'id'}, update: {:$inc => {count: 1}})
  id = counters.find[0]['count']
  # insert the new image
  data = Hash[_id: id.to_i].merge(meta)
  db.collection('images').insert(data)
end

# Update an image's metadata
#
# @param id [Integer] the image's id to update
# @param update [Hash] the the image's metadata to update
# @return [Array] the updated image's metadata or empty if image not found
#
# TODO if update comes as {name: 'x', ...} the following happens, it need to come as {'name' => 'x',...}:
  # actual: {"_id"=>45, "name"=>"Ubuntu abc", "architecture"=>"x86_64"}
  # update:             {name: 'Ubuntu xyz', architecture: 'i386', a: 'y'}
  # result: {"_id"=>45, "name"=>"Ubuntu xyz", "architecture"=>"i386", "a"=>"y", :name=>"Ubuntu xyz", :architecture=>"i386", :a=>"y"}
  # altought, visible from the mongo console, when retrieving from the code it does not return that extra :x=>"y" values, but they are in the db!
def put_image(id, update)
  # validate data and connect to db
  validate_data(update) #TODO: Image data validation
  images = configure_db('images')
  # find image to update
  res = images.find({_id: id})
  # if image was not found 'res' is an empty array so return it
  return res if res.empty?
  # update image's metadata
  meta = res.first
  meta.merge!(update)
  images.update({_id: id}, meta, {upsert: 'true'})
  meta
end


EventMachine.synchrony do
  data = {
      name: 'Ubuntu abc',
      architecture: 'x86_64',
      access: 'public',
      type: 'amazon',
      disk: 'ami',
      store: 's3'
  }

  up = {
      name: 'Ubuntu xyz',
      architecture: 'i386',
      a: 'y'
  }

  up1 = {
      'name' => 'Ubuntu xyz',
      'architecture' => 'i386',
      'a' => 'y'
  }

  #p = post_image(data).inspect
  #p = delete_image(44).inspect
  p = put_image(45, up)
  get_public_images.each { |a| puts a }

  puts '-', p.inspect
  EventMachine.stop

end


#
#puts data
#puts JSON.generate(data)
#

#db.counters.insert({_id:"id", count:1})

#var o = db.counters.findAndModify({query: {_id: "id"}, update: {$inc: {count: 1}}});
#db.images.save({_id:o.count, ...})
#var o = db.counters.findAndModify({query: {_id: "id"}, update: {$inc: {count: 1}}});
#db.images.save({_id:o.count, ...})
#
#{ "_id" : 1, "name" : "Ubuntu 11.04 Server", "architecture" : "x86_64", "access" : "public", "store" : "swift", "other" : { "release" : 2011 } }
#{ "_id" : 2, "name" : "CentOS 6.0", "architecture" : "x86_64", "access" : "public", "store" : "swift", "disk" : "vmdk", "other" : { "release" : 2010 } }
#{ "_id" : 3, "name" : "Ubuntu 11.10", "architecture" : "i386", "access" : "public", "store" : "s3", "other" : { "release" : 2011 } }
