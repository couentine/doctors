# FROM (http://artsy.github.io/blog/2013/11/07/upgrading-to-mongoid4/)
#
# "If you're using Warden (including via Devise) and/or rely on session cookies that may contain a 
# user ID, add an implementation for the deprecated Moped::BSON::Document. This will prevent all 
# old cookies from causing a serialization error and logging all those users out."

module Moped
  module BSON
    ObjectId = ::BSON::ObjectId

    class Document < Hash
      class << self
        def deserialize(io, document = new)
          __bson_load__(io, document)
        end

        def serialize(document, io = "")
          document.__bson_dump__(io)
        end
      end
    end
  end
end