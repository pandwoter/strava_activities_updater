# frozen_string_literal: true

require 'strava-ruby-client'

######################################
#          GENERIC SECTION           #
######################################

REFRESH_TOKEN = ENV.fetch('REFRESH_TOKEN')

APP_CREDS = {
  client_id: ENV.fetch('CLIENT_ID'),
  client_secret: ENV.fetch('CLIENT_SECRET')
}.freeze

IDIVIDUAL_CREDS = {
  access_token: BASE_ACCESS_TOKEN
}.freeze

ACTIVITIES_MAPPING = {
  /run/i => '🏃',
  /weight/i => '🏋️‍♀️',
  /ride/i => '🚴‍♂️'
}.freeze

def app_client
  @app_client ||= Strava::OAuth::Client.new(**APP_CREDS)
end

def refreshed_access_token(force: false)
  refresh_token = proc do
    app_client
      .oauth_token(refresh_token: REFRESH_TOKEN, grant_type: 'refresh_token')
      .slice('access_token').symbolize_keys
  end

  if force
    @refreshed_token = refresh_token.call
  else
    @refreshed_token ||= refresh_token.call
  end
end

def with_refreshing_stale_tokens(&block)
  block.call
rescue Strava::Errors::Fault => e
  raise(e) unless e.code == 403

  refreshed_access_token(force: true)
  block.call
end

def individual_client
  @individual_client ||= Strava::Api::Client.new(**refreshed_access_token)
end

######################################
#             API CALLS              #
######################################

Activity = Struct.new(:id, :name) do
  def new_name
    ACTIVITIES_MAPPING[@type]
  end

  def match?
    @type = ACTIVITIES_MAPPING.keys.find { _1.match?(name) }
    @type ? true : false
  end
end

def list_of_recent_activities
  serialize_activities = ->(activity) { Activity.new(*activity.values_at('id', 'name')) }
  activities = with_refreshing_stale_tokens { individual_client.athlete_activities }
  activities.map(&serialize_activities)
end

def candidates_for_renaming
  list_of_recent_activities.filter(&:match?)
end

def log_info(id, old_name, new_name)
  puts <<~COMMENT
    Activity ID: #{id}, has been re-named from: #{old_name} to: #{new_name}
  COMMENT
end

def update_activity_name(id, new_name)
  with_refreshing_stale_tokens do
    individual_client.update_activity(id: id, name: new_name)
  end
end

def rename!
  candidates_for_renaming.each do |candidate|
    update_activity_name(candidate.id, candidate.new_name)
    log_info(candidate.id, candidate.name, candidate.new_name)
  end
end
