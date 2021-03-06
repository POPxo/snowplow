# Copyright (c) 2012-2018 Snowplow Analytics Ltd. All rights reserved.
#
# This program is licensed to you under the Apache License Version 2.0,
# and you may not use this file except in compliance with the Apache License Version 2.0.
# You may obtain a copy of the Apache License Version 2.0 at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the Apache License Version 2.0 is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the Apache License Version 2.0 for the specific language governing permissions and limitations there under.

# Author::    Ben Fradet (mailto:support@snowplowanalytics.com)
# Copyright:: Copyright (c) 2012-2018 Snowplow Analytics Ltd
# License::   Apache License Version 2.0

require 'aws-sdk-s3'
require 'contracts'
require 'pathname'
require 'uri'

module Snowplow
  module EmrEtlRunner
    module S3

      include Contracts

      # Check a location on S3 is empty.
      #
      # Parameters:
      # +client+:: S3 client
      # +location+:: S3 url of the folder to check for emptiness
      # +key_filter+:: filter to apply on the keys, filters folders and $folder$ files by default
      def empty?(client, location,
          key_filter = lambda { |k| !(k =~ /\/$/) and !(k =~ /\$folder\$$/) })
        bucket, prefix = parse_bucket_prefix(location)
        empty_impl(client, bucket, prefix, key_filter)
      end

      # List all object names satisfying a key filter.
      #
      # Parameters:
      # +client+:: S3 client
      # +location+:: S3 url of the folder to list the object names for
      # +key_filter+:: filter to apply on the keys
      def list_object_names(client, location, key_filter)
        bucket, prefix = parse_bucket_prefix(location)
        list_object_names_impl(client, bucket, prefix, key_filter)
      end

      # Extract the bucket and prefix from an S3 url.
      #
      # Parameters:
      # +location+:: the S3 url to parse
      Contract String => [String, String]
      def parse_bucket_prefix(location)
        u = URI.parse(location)
        return u.host, u.path[1..-1]
      end

    private

      def list_object_names_impl(client, bucket, prefix, key_filter, max_keys = 50, token = nil)
        response = list_objects(client, bucket, prefix, max_keys, token)
        filtered = response.contents
          .select { |c| key_filter[c.key] }
          .map { |c| c.key }
        if response.is_truncated
          filtered + list_object_names_impl(
            client, bucket, prefix, key_filter, max_keys, response.next_continuation_token)
        else
          filtered
        end
      end

      def empty_impl(client, bucket, prefix, key_filter, max_keys = 50, token = nil)
        response = list_objects(client, bucket, prefix, max_keys, token)
        filtered = response.contents.select { |c| key_filter[c.key] }
        if filtered.empty?
          if response.is_truncated
            empty_impl(client, bucket, prefix, key_filter, max_keys, response.next_continuation_token)
          else
            true
          end
        else
          false
        end
      end

      def list_objects(client, bucket, prefix, max_keys, token)
        options = {
          bucket: bucket,
          prefix: prefix,
          max_keys: max_keys,
        }
        options[:continuation_token] = token if !token.nil?
        client.list_objects_v2(options)
      end

    end
  end
end
