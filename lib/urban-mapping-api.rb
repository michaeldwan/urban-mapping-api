require 'curl'
require 'json'
require 'digest'
require 'ostruct'
require 'uri'
require "#{File.dirname(__FILE__)}/core_ext"

module UrbanMapping
  class RequestError < StandardError
    attr_reader :code, :url, :message
    def initialize(code, url, message)
      @code = code
      @url = url
      @message = message
    end
  end
  
  class NeighborhoodOpenStruct < OpenStruct
    def id
      @table[:id] || super
    end
  end
  
  class Interface
    ENDPOINT = 'http://api1.urbanmapping.com/neighborhoods/rest'

    attr_reader :api_key, :shared_secret, :options3
    
    # Create a new instance.
    # Requeres an api_key. A shared key needs to be provided for 
    # access to premium API methods.
    def initialize(api_key, options = {})
      options = {
        :raw => false
      }.merge(options)
      @api_key = api_key
      @shared_secret = options.delete(:shared_secret)
      @options = options
    end
    
    # Returns true if a shard_secret was provided to the constructor.
    def premium_api?
      !shared_secret.nil?
    end
    
    # Returns a list of neighborhoods whose boundaries contain the requested 
    # latitude and longitude.
    def get_neighborhoods_by_lat_lng(latitude, longitude)
      perform('getNeighborhoodsByLatLng', :lat => latitude, :lng => longitude)
    end

    # Returns the neighborhood whose centroid is nearest to the requested 
    # latitude and longitude within a 20 linear mile range.
    def get_nearest_neighborhood(latitude, longitude)
      perform('getNearestNeighborhood', :lat => latitude, :lng => longitude)
    end
    
    # Returns a list of neighborhoods within a bounding box extent defined by 
    # southwestern and northeastern corners. Note query extents covering more 
    # than 45 square miles will be rejected.
    def get_neighborhoods_by_extent(southwest_latitude, southwest_longitude, northeast_latitude, northeast_longitude)
      perform('getNeighborhoodsByExtent', :swlat => southwest_latitude, 
                                          :swlng => southwest_longitude,
                                          :nelat => northeast_latitude,
                                          :nelng => northeast_longitude)
    end

    # This method first geocodes the input address, then returns the geocode 
    # and lists neighborhoods containing the point in a single response. 
    # This is technically executed in a single request, but for the purposes 
    # of account administration a single invocation is counted as two calls.
    def get_neighborhoods_by_address(street, city, state, country = 'USA')
      perform('getNeighborhoodsByAddress', :street => street,
                                           :city => city,
                                           :state => state,
                                           :country => country)
    end
    
    # Returns a list of neighborhood for the requested city.
    def get_neighborhoods_by_city_state_country(city, state, country = 'USA')
      perform('getNeighborhoodsByCityStateCountry', :city => city,
                                                    :state => state,
                                                    :country => country)
    end

    # Returns a list of neighborhoods whose areas intersect that of the requested postal code.
    def get_neighborhoods_by_postal_code(postal_code)
      perform('getNeighborhoodsByPostalCode', :postalCode => postal_code)
    end
    
    # Returns a list of neighborhoods for the requested neighborhood name.
    def get_neighborhoods_by_name(name)
      perform('getNeighborhoodsByName', :name => name)
    end
    
    # Returns neighborhood details for the requested neighborhood ID.
    def get_neighborhood_detail(id)
      perform('getNeighborhoodDetail', :neighborhoodId => id)
    end
    
    # Returns neighborhood relationship attributes for the requested neighborhood ID.
    def get_neighborhood_relationships(id)
      perform('getNeighborhoodRelationships', :neighborhoodId => id)
    end

    private
      def generate_signature
        Digest::MD5.hexdigest([api_key, shared_secret, Time.now.utc.to_i.to_s].join)
      end

      def perform(method, parameters)
        parameters.merge!({
          :format => 'json',
          :apikey => api_key
        })
        parameters.merge!(:sig => generate_signature) if premium_api?
        
        query_string = parameters.to_a.map{ |x| x.map{|val| URI.encode(val.to_s)}.join('=') }.join('&')

        url = "#{ENDPOINT}/#{method}?#{query_string}"
        response = Curl::Easy.perform(url)

        if response.response_code != 200
          raise RequestError.new(response.response_code, url, response.body_str)
        end
        
        output = JSON.parse(response.body_str)
        
        return output if parameters[:raw]

        output.to_openstruct
      rescue StandardError => ex
        raise "An error occured while calling #{url}: #{ex.message}\n#{ex.backtrace}"
      end
  end  
end
