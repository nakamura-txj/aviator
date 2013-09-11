require 'test_helper'

class Aviator::Test

  describe 'aviator/openstack/compute/v2/admin/resize_server' do

    def create_request(session_data = get_session_data)
      klass.new(session_data) do |params|
        params[:id]        = server[:id]
        params[:name]      = 'Aviator Server'
        params[:flavorRef] = flavor_id
      end
    end


    def get_session_data
      session.send :auth_info
    end


    def helper
      Aviator::Test::RequestHelper
    end


    def klass
      @klass ||= helper.load_request('openstack', 'compute', 'v2', 'admin', 'resize_server.rb')
    end


    def session
      unless @session
        @session = Aviator::Session.new(
                     config_file: Environment.path,
                     environment: 'openstack_admin'
                   )

        @session.authenticate
      end

      @session
    end


    def server
      unless @server
        response = session.compute_service.request(:list_servers) do |params|
                     params[:details]     = true
                     params[:all_tenants] = true
                   end

        current_tenant = get_session_data[:access][:token][:tenant]
        active_servers = response.body[:servers].select do |server| 
                           server[:status] == 'ACTIVE' && server[:tenant_id] == current_tenant[:id]
                         end
        
        raise "\n\nProject '#{ current_tenant[:name] }' should have at least 1 server with "\
              "a status of ACTIVE\n\n" if active_servers.empty?

        @server = active_servers.first
      end
      
      @server
    end


    def flavor_id
      ids = session.compute_service.request(:list_flavors).body[:flavors].map{ |f| f['id'] }
      ids.delete(server[:flavor][:id])

      @flavor_id ||= ids.first
    end


    validate_attr :anonymous? do
      klass.anonymous?.must_equal false
    end


    validate_attr :api_version do
      klass.api_version.must_equal :v2
    end


    validate_attr :body do
      request = create_request

      klass.body?.must_equal true
      request.body?.must_equal true
      request.body.wont_be_nil
    end


    validate_attr :endpoint_type do
      klass.endpoint_type.must_equal :admin
    end


    validate_attr :headers do
      headers = { 'X-Auth-Token' => get_session_data[:access][:token][:id] }

      request = create_request

      request.headers.must_equal headers
    end


    validate_attr :http_method do
      create_request.http_method.must_equal :post
    end


    validate_attr :required_params do
      klass.required_params.must_equal [
        :id,
        :name,
        :flavorRef
      ]
    end


    validate_attr :url do
      service_spec = get_session_data[:access][:serviceCatalog].find{|s| s[:type] == 'compute' }
      url          = "#{ service_spec[:endpoints][0][:publicURL] }/servers/#{ server[:id] }/action"

      request = create_request do |params|
        params[:id]  = server[:id]
        params[:flavorRef] = flavor_id
        params[:name] = 'Aviator Server'
      end

      request.url.must_equal url
    end


    validate_response 'parameters are provided' do
      response = session.compute_service.request :resize_server do |params|
        params[:id]        = server[:id]
        params[:flavorRef] = flavor_id
        params[:name]      = 'Aviator Server'
      end

      response.status.must_equal 202
      response.headers.wont_be_nil
    end


    validate_response 'the id parameter is invalid' do
      flavor_id = session.compute_service.request(:list_flavors).body[:flavors].first[:id]

      response = session.compute_service.request :resize_server do |params|
        params[:id]        = 'invalidvalue'
        params[:flavorRef] = flavor_id
        params[:name]      = 'Aviator Server'
      end

      response.status.must_equal 404
      response.body.wont_be_nil
      response.headers.wont_be_nil
    end


    validate_response 'the flavorRef parameter is invalid' do
      response = session.compute_service.request :resize_server do |params|
        params[:id]        = server[:id]
        params[:flavorRef] = 'invalidvalue'
        params[:name]      = 'Aviator Server'
      end

      response.status.must_equal 400
      response.body.wont_be_nil
      response.headers.wont_be_nil
    end

  end

end
