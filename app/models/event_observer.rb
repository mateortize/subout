class EventObserver < Mongoid::Observer
  observe :event

  def after_create(event)
    Pusher['event'].trigger!('created', EventSerializer.new(event).as_json)
  end
end
