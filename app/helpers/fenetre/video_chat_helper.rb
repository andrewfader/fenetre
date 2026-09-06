# frozen_string_literal: true

module Fenetre
  module VideoChatHelper
    # Helper method to render the video chat container with proper data attributes
    def fenetre_video_chat_container(room_id, user_id, theme: 'dark', ice_servers: nil)
      content = stylesheet_link_tag('fenetre/video_chat', media: 'all')
      content + video_chat_main_container(room_id, user_id, theme, ice_servers)
    end

    private

    def video_chat_main_container(room_id, user_id, theme, ice_servers)
      servers = ice_servers || Fenetre.ice_servers
      content_tag(:div, class: "fenetre-video-chat-container fenetre-theme-#{theme}", data: {
                    controller: 'fenetre--video-chat',
                    fenetre__video_chat_user_id_value: user_id.to_s,
                    fenetre__video_chat_ice_servers_value: servers,
                    fenetre__video_chat_max_video_bitrate_value: Fenetre.max_video_bitrate,
                    fenetre__video_chat_max_audio_bitrate_value: Fenetre.max_audio_bitrate,
                    fenetre__video_chat_video_width_value: Fenetre.video_width,
                    fenetre__video_chat_video_height_value: Fenetre.video_height,
                    fenetre__video_chat_frame_rate_value: Fenetre.frame_rate,
                    fenetre_theme: theme
                  }) do
        hidden_room_id_input(room_id) +
          connection_status_indicator +
          content_tag(:div, class: 'fenetre-stage') do
            local_video_section + remote_videos_section
          end +
          media_control_section +
          content_tag(:div, class: 'fenetre-sidebar') do
            section_heading('Participants') +
              participants_list +
              section_heading('Chat') +
              chat_section
          end
      end
    end

    def connection_status_indicator
      content_tag(:div, 'Connecting...',
                  class: 'fenetre-connection-status',
                  data: { fenetre__video_chat_target: 'connectionStatus' })
    end

    def hidden_room_id_input(room_id)
      content_tag(:input, nil, type: 'hidden', value: room_id, data: { fenetre__video_chat_target: 'roomId' })
    end

    def section_heading(text)
      content_tag(:h3, text)
    end

    def participants_list
      content_tag(:ul, '', class: 'fenetre-participant-list', data: { fenetre__video_chat_target: 'participants' })
    end

    def local_video_section
      content_tag(:div, class: 'fenetre-video-section fenetre-local-section') do
        content_tag(:video, '',
                    data: { fenetre__video_chat_target: 'localVideo' },
                    autoplay: true,
                    playsinline: true,
                    muted: true,
                    class: 'fenetre-local-video')
      end
    end

    def media_control_section
      content_tag(:div, class: 'fenetre-controls', role: 'toolbar', 'aria-label': 'Call controls') do
        toggle_button('Camera', 'toggleVideo', 'Turn off camera') +
          toggle_button('Mic', 'toggleAudio', 'Mute microphone') +
          toggle_button('Share Screen', 'toggleScreenShare', 'Share screen')
      end
    end

    def toggle_button(label, action, aria_label = nil)
      content_tag(:button, label,
                  type: 'button',
                  data: { action: "fenetre--video-chat##{action}" },
                  class: 'fenetre-control-button',
                  'aria-label': aria_label || label,
                  'aria-pressed': 'false')
    end

    def remote_videos_section
      content_tag(:div, class: 'fenetre-video-section fenetre-remote-section') do
        content_tag(:div, '', data: { fenetre__video_chat_target: 'remoteVideos' },
                              class: 'fenetre-remote-grid')
      end
    end

    def chat_section
      content_tag(:div, class: 'fenetre-chat-container') do
        chat_messages + chat_input_container
      end
    end

    def chat_messages
      content_tag(:div, '', data: { fenetre__video_chat_target: 'chatMessages' }, class: 'fenetre-chat-messages')
    end

    def chat_input_container
      content_tag(:div, class: 'fenetre-chat-input-container') do
        content_tag(:input, nil, type: 'text', placeholder: 'Message the room…',
                                 maxlength: 2000,
                                 autocomplete: 'off',
                                 data: {
                                   fenetre__video_chat_target: 'chatInput',
                                   action: 'keydown.enter->fenetre--video-chat#sendChat'
                                 }) +
          content_tag(:button, 'Send', type: 'button',
                                       data: { action: 'fenetre--video-chat#sendChat' },
                                       class: 'fenetre-chat-send-button')
      end
    end
  end
end
