require "test_helper"

class Api::V1::ImagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @window_schedule_repair = window_schedule_repairs(:one)
    @window = windows(:one)
    @window.update!(window_schedule_repair: @window_schedule_repair)

    # Mock authentication
    sign_in @user
    @headers = { "Authorization": "Bearer #{@user.create_new_auth_token["access-token"]}" }
  end

  test "should upload window image" do
    # Create a mock image file
    image_file = fixture_file_upload("files/test_image.jpg", "image/jpeg")

    assert_difference("ActiveStorage::Attachment.count") do
      post api_v1_images_upload_window_image_path,
           params: { window_id: @window.id, image: image_file },
           headers: @headers
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert json_response["image_url"]
    assert json_response["image_name"]
  end

  test "should upload multiple images to WRS" do
    # Create mock image files
    image_files = [
      fixture_file_upload("files/test_image.jpg", "image/jpeg"),
      fixture_file_upload("files/test_image2.jpg", "image/jpeg")
    ]

    assert_difference("ActiveStorage::Attachment.count", 2) do
      post api_v1_images_upload_multiple_images_path,
           params: { window_schedule_repair_id: @window_schedule_repair.id, images: image_files },
           headers: @headers
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal 2, json_response["image_count"]
    assert_equal 2, json_response["image_urls"].length
  end

  test "should reject upload without image" do
    post api_v1_images_upload_window_image_path,
         params: { window_id: @window.id },
         headers: @headers

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["error"]
  end
end
