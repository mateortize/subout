unless Rails.env.development? || Rails.env.test?
  Airbrake.configure do |config|
    config.api_key = ENV['AIRBRAKE_API_KEY']
  end
end
