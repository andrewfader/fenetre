# frozen_string_literal: true

module Fenetre
  module VideoChatHelper
    # Helper method to render the video chat container with proper data attributes
    def fenetre_video_chat_container(room_id, user_id, theme: 'dark')
      # Ensure the stylesheet is included
      out = stylesheet_link_tag('fenetre/video_chat', media: 'all')
      out << tag.div(class: "fenetre-video-chat-container fenetre-theme-#{theme}", data: {
                       controller: 'fenetre--video-chat',
                       fenetre_video_chat_user_id_value: user_id.to_s,
                       fenetre_theme: theme
                     }) do
        concat tag.input(
          type: 'hidden',
          value: room_id,
          data: { fenetre_video_chat_target: 'roomId' }
        )
        concat tag.h3('Participants')
        concat tag.ul('', id: 'fenetre-participant-list')
        concat tag.h3('My Video')
        concat tag.div(class: 'fenetre-video-section') {
          tag.video(nil, data: { fenetre_video_chat_target: 'localVideo' }, autoplay: true, playsinline: true,
                         muted: true, style: 'width: 200px; height: 150px;')
        }
        concat tag.h3('Remote Videos')
        concat tag.div(class: 'fenetre-video-section') {
          tag.div(nil, data: { fenetre_video_chat_target: 'remoteVideos' })
        }
        concat tag.h3('Chat')
        concat tag.div('', id: 'fenetre-chat-box')
      end
      out.html_safe
    end
  end
end
