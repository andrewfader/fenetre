# frozen_string_literal: true

module Fenetre
  module VideoChatHelper
    # Helper method to render the video chat container with proper data attributes
    def fenetre_video_chat_container(room_id, user_id, theme: 'dark')
      content = stylesheet_link_tag('fenetre/video_chat', media: 'all')
      content + video_chat_main_container(room_id, user_id, theme)
    end

    private

    def video_chat_main_container(room_id, user_id, theme)
      content_tag(:div, class: "fenetre-video-chat-container fenetre-theme-#{theme}", data: {
                    controller: 'fenetre--video-chat',
                    fenetre_video_chat_user_id_value: user_id.to_s,
                    fenetre_theme: theme
                  }) do
        hidden_room_id_input(room_id) +
          section_heading('Participants') +
          participants_list +
          section_heading('My Video') +
          local_video_section +
          media_control_section +
          section_heading('Remote Videos') +
          remote_videos_section +
          section_heading('Chat') +
          chat_section
      end
    end

    def hidden_room_id_input(room_id)
      content_tag(:input, nil, type: 'hidden', value: room_id, data: { fenetre_video_chat_target: 'roomId' })
    end

    def section_heading(text)
      content_tag(:h3, text)
    end

    def participants_list
      content_tag(:ul, '', id: 'fenetre-participant-list')
    end

    def local_video_section
      content_tag(:div, class: 'fenetre-video-section') do
        content_tag(:video, '', data: { fenetre_video_chat_target: 'localVideo' }, autoplay: true, playsinline: true,
                                muted: true, style: 'width: 200px; height: 150px;')
      end
    end

    def media_control_section
      content_tag(:div, class: 'fenetre-control-section') do
        toggle_button('Toggle Video', 'toggleVideo') +
          toggle_button('Toggle Audio', 'toggleAudio')
      end
    end

    def toggle_button(label, action)
      content_tag(:button, label, data: { action: "fenetre--video-chat##{action}" }, class: 'fenetre-control-button')
    end

    def remote_videos_section
      content_tag(:div, class: 'fenetre-video-section') do
        content_tag(:div, '', data: { fenetre_video_chat_target: 'remoteVideos' })
      end
    end

    def chat_section
      content_tag(:div, class: 'fenetre-chat-container') do
        chat_messages + chat_input_container
      end
    end

    def chat_messages
      content_tag(:div, '', data: { fenetre_video_chat_target: 'chatMessages' }, class: 'fenetre-chat-messages')
    end

    def chat_input_container
      content_tag(:div, class: 'fenetre-chat-input-container') do
        content_tag(:input, nil, type: 'text', placeholder: 'Type your message...',
                                 data: { fenetre_video_chat_target: 'chatInput' }) +
          content_tag(:button, 'Send', data: { action: 'fenetre--video-chat#sendChat' },
                                       class: 'fenetre-chat-send-button')
      end
    end
  end
end
