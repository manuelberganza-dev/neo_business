class SalesChannel < ApplicationCable::Channel
  def subscribed
    require_permission!("sales.read")
    stream_for_store(:sales)
  end
end
