# frozen_string_literal: true

module Fenetre
  module VideoChatHelper
    # Helper method to render the video chat container with proper data attributes
    def fenetre_video_chat_container(room_id, user_id, theme: 'dark')
      # Ensure the stylesheet is included
      content = stylesheet_link_tag('fenetre/video_chat', media: 'all')
      
      # Build the main container
      content_tag = content_tag(:div, class: "fenetre-video-chat-container fenetre-theme-#{theme}", data: {
        controller: 'fenetre--video-chat',
        fenetre_video_chat_user_id_value: user_id.to_s,
        fenetre_theme: theme
      }) do
        # Room ID input
        hidden_input = content_tag(:input, nil, type: 'hidden', value: room_id, 
                                  data: { fenetre_video_chat_target: 'roomId' })
        
        # Participants section
        participants_heading = content_tag(:h3, 'Participants')
        participants_list = content_tag(:ul, '', id: 'fenetre-participant-list')
        
        # Local video section
        local_video_heading = content_tag(:h3, 'My Video')
        local_video_section = content_tag(:div, class: 'fenetre-video-section') do
          content_tag(:video, '', data: { fenetre_video_chat_target: 'localVideo' },
                    autoplay: true, playsinline: true, muted: true,
                    style: 'width: 200px; height: 150px;')
        end
        
        # Media controls
        control_section = content_tag(:div, class: 'fenetre-control-section') do
          toggle_video = content_tag(:button, 'Toggle Video', 
                                    data: { action: 'fenetre--video-chat#toggleVideo' }, 
                                    class: 'fenetre-control-button')
          toggle_audio = content_tag(:button, 'Toggle Audio', 
                                    data: { action: 'fenetre--video-chat#toggleAudio' }, 
                                    class: 'fenetre-control-button')
          toggle_video + toggle_audio
        end
        
        # Remote videos section
        remote_heading = content_tag(:h3, 'Remote Videos')
        remote_section = content_tag(:div, class: 'fenetre-video-section') do
          content_tag(:div, '', data: { fenetre_video_chat_target: 'remoteVideos' })
        end
        
        # Chat section
        chat_heading = content_tag(:h3, 'Chat')
        chat_container = content_tag(:div, class: 'fenetre-chat-container') do
          # Chat messages
          chat_messages = content_tag(:div, '', 
                                     data: { fenetre_video_chat_target: 'chatMessages' }, 
                                     class: 'fenetre-chat-messages')
          
          # Chat input
          chat_input_container = content_tag(:div, class: 'fenetre-chat-input-container') do
            input = content_tag(:input, nil, type: 'text', 
                              placeholder: 'Type your message...', 
                              data: { fenetre_video_chat_target: 'chatInput' })
            send_button = content_tag(:button, 'Send', 
                                     data: { action: 'fenetre--video-chat#sendChat' }, 
                                     class: 'fenetre-chat-send-button')
            input + send_button
          end
          
          chat_messages + chat_input_container
        end
        
        # Combine all elements
        hidden_input + participants_heading + participants_list + 
        local_video_heading + local_video_section + 
        control_section + remote_heading + remote_section + 
        chat_heading + chat_container
      end
      
      # Return the complete HTML
      content + content_tag
    end
  end
end
