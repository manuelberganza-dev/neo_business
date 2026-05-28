class InventoryChannel < ApplicationCable::Channel
  def subscribed
    require_permission!("inventory_items.read")
    stream_for_store(:inventory)
  end
end
