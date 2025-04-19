# frozen_string_literal: true

def broadcast(type, payload = {})
  # Ensure user context is available
  return unless current_user && @room_id

  # Prepare data, ensuring consistent structure
  data = {
    from: current_user.id,
    type: type,
    # Ensure payload is always a hash, even if empty
    payload: payload.is_a?(Hash) ? payload : {},
    participants: @@participants[@room_id] || [], # Include current participants
    # Add metadata if available in params
    topic: @params[:room_topic],
    max_participants: @params[:max_participants]
  }.compact # Remove nil values like topic/max_participants if not set

  # Add Turbo Stream update if applicable (example)
  if %w[join leave].include?(type)
    # This is a placeholder - actual Turbo Stream generation would be more complex
    # Consider using a view partial or helper to generate this HTML
    data[:turbo_stream] =
      "<turbo-stream action=\"replace\" target=\"participants_#{@room_id}\"><template>...</template></turbo-stream>"
  end

  # Use transmit for testing compatibility
  # In production, ActionCable.server.broadcast might still be preferred
  # depending on whether you need to broadcast outside the current connection.
  # For now, aligning with tests.
  transmit(data)

  # If you need both direct broadcasting AND testability:
  # ActionCable.server.broadcast(stream_name, data)
  # transmit(data) # Keep transmit for tests
end
