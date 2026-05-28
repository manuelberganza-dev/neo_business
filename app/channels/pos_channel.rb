class PosChannel < ApplicationCable::Channel
  def subscribed
    require_permission!("sales.read")
    stream_for_store(:pos)
  end
end
