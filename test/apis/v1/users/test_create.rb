require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestCreate < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    ApiUser.where(:registration_source.ne => "seed").delete_all
  end

  def test_valid_create
    non_admin_auth = non_admin_key_creator_api_key
    attributes = FactoryGirl.attributes_for(:api_user)
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_auth).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_equal(attributes[:last_name], data["user"]["last_name"])

    user = ApiUser.find(data["user"]["id"])
    assert_equal(attributes[:last_name], user.last_name)

    assert_equal(1, active_count - initial_count)
  end

  def test_api_key_format
    attributes = FactoryGirl.attributes_for(:api_user)
    refute(attributes["api_key"])

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert(data["user"]["api_key"])
    assert_equal(40, data["user"]["api_key"].length)
    assert_match(/\A[0-9A-Za-z]+\z/, data["user"]["api_key"])
  end

  def test_no_user_attributes_error
    non_admin_auth = non_admin_key_creator_api_key
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_auth).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => nil,
    }))
    assert_response_code(422, response)

    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def test_user_attributes_unexpected_object_error
    non_admin_auth = non_admin_key_creator_api_key
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_auth).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => "something" },
    }))

    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def test_wildcard_cors
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => FactoryGirl.attributes_for(:api_user) },
    }))
    assert_response_code(201, response)
    assert_equal("*", response.headers["Access-Control-Allow-Origin"])
  end

  def test_permits_private_fields_as_admin
    attributes = FactoryGirl.attributes_for(:api_user, :roles => ["admin"])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    user = ApiUser.find(data["user"]["id"])
    assert_equal(["admin"], user.roles)
  end

  def test_ignores_private_fields_as_non_admin
    attributes = FactoryGirl.attributes_for(:api_user, :roles => ["admin"])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    user = ApiUser.find(data["user"]["id"])
    assert_nil(user.roles)
  end

  def test_registration_source_default
    attributes = FactoryGirl.attributes_for(:api_user)
    assert_nil(attributes[:registration_source])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_equal("api", data["user"]["registration_source"])
  end

  def test_registration_source_custom
    attributes = FactoryGirl.attributes_for(:api_user, :registration_source => "whatever")
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_equal("whatever", data["user"]["registration_source"])
  end

  def test_captures_and_returns_requester_details_as_admin
    attributes = FactoryGirl.attributes_for(:api_user)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => {
        "Content-Type" => "application/x-www-form-urlencoded",
        "X-Forwarded-For" => "1.2.3.4",
        "User-Agent" => "foo",
        "Referer" => "http://example.com/foo",
        "Origin" => "http://example.com",
      },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_equal("1.2.3.4", data["user"]["registration_ip"])
    assert_equal("foo", data["user"]["registration_user_agent"])
    assert_equal("http://example.com/foo", data["user"]["registration_referer"])
    assert_equal("http://example.com", data["user"]["registration_origin"])

    user = ApiUser.find(data["user"]["id"])
    assert_equal("1.2.3.4", user.registration_ip)
    assert_equal("foo", user.registration_user_agent)
    assert_equal("http://example.com/foo", user.registration_referer)
    assert_equal("http://example.com", user.registration_origin)
  end

  def test_captures_does_not_return_requester_details_as_non_admin
    attributes = FactoryGirl.attributes_for(:api_user)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => {
        "Content-Type" => "application/x-www-form-urlencoded",
        "X-Forwarded-For" => "1.2.3.4",
        "User-Agent" => "foo",
        "Referer" => "http://example.com/foo",
        "Origin" => "http://example.com",
      },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_nil(data["user"]["registration_ip"])
    assert_nil(data["user"]["registration_user_agent"])
    assert_nil(data["user"]["registration_referer"])
    assert_nil(data["user"]["registration_origin"])

    user = ApiUser.find(data["user"]["id"])
    assert_equal("1.2.3.4", user.registration_ip)
    assert_equal("foo", user.registration_user_agent)
    assert_equal("http://example.com/foo", user.registration_referer)
    assert_equal("http://example.com", user.registration_origin)
  end

  def test_registration_ip_x_forwarded_last_trusted
    attributes = FactoryGirl.attributes_for(:api_user)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => {
        "Content-Type" => "application/x-www-form-urlencoded",
        "X-Forwarded-For" => "1.1.1.1, 2.2.2.2, 127.0.0.1",
        "User-Agent" => "foo",
        "Referer" => "https://example.com/foo",
        "Origin" => "https://example.com",
      },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_equal("2.2.2.2", data["user"]["registration_ip"])
  end

  def test_custom_rate_limits_reject_same_duration_and_limit_by
    attributes = FactoryGirl.attributes_for(:api_user, {
      :settings => FactoryGirl.attributes_for(:custom_rate_limit_api_setting, {
        :rate_limits => [
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 5000, :limit_by => "ip", :limit => 10),
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 5000, :limit_by => "ip", :limit => 20),
        ],
      }),
    })

    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_response_code(422, response)

    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    assert_equal(0, active_count - initial_count)
  end

  def test_custom_rate_limits_accept_same_duration_different_limit_by
    attributes = FactoryGirl.attributes_for(:api_user, {
      :settings => FactoryGirl.attributes_for(:custom_rate_limit_api_setting, {
        :rate_limits => [
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 5000, :limit_by => "ip", :limit => 10),
          FactoryGirl.attributes_for(:api_rate_limit, :duration => 5000, :limit_by => "apiKey", :limit => 20),
        ],
      }),
    })

    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => attributes },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_equal(2, data["user"]["settings"]["rate_limits"].length)

    user = ApiUser.find(data["user"]["id"])
    assert_equal(2, user.settings.rate_limits.length)

    assert_equal(1, active_count - initial_count)
  end

  private

  def non_admin_key_creator_api_key
    user = FactoryGirl.create(:api_user, {
      :roles => ["api-umbrella-key-creator"],
    })

    { :headers => { "X-Api-Key" => user["api_key"] } }
  end

  def active_count
    ApiUser.where(:deleted_at => nil).count
  end
end
