namespace :s3 do
  desc "Test S3 connection and list buckets"
  task test_connection: :environment do
    begin
      s3_client = Aws::S3::Client.new(
        region: 'eu-north-1',
        access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
        secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key)
      )

      puts "✅ S3 connection successful!"

      # List buckets
      response = s3_client.list_buckets
      puts "\nAvailable buckets:"
      response.buckets.each do |bucket|
        puts "  - #{bucket.name} (created: #{bucket.creation_date})"
      end

      # Test specific bucket access
      bucket_name = 'bullet-services'
      begin
        s3_client.head_bucket(bucket: bucket_name)
        puts "\n✅ Bucket '#{bucket_name}' is accessible"

        # List objects in bucket
        objects = s3_client.list_objects_v2(bucket: bucket_name)
        puts "  Objects in bucket: #{objects.contents.count}"

      rescue Aws::S3::Errors::NoSuchBucket
        puts "\n❌ Bucket '#{bucket_name}' does not exist"
      rescue Aws::S3::Errors::AccessDenied
        puts "\n❌ Access denied to bucket '#{bucket_name}'"
      end

    rescue => e
      puts "❌ S3 connection failed: #{e.message}"
      puts "\nMake sure you have configured your AWS credentials:"
      puts "  rails credentials:edit"
      puts "\nAdd:"
      puts "  aws:"
      puts "    access_key_id: your_access_key"
      puts "    secret_access_key: your_secret_key"
    end
  end

  desc "Upload test image to S3"
  task upload_test_image: :environment do
    begin
      # Create a test image file
      test_image_path = Rails.root.join('tmp', 'test_image.jpg')
      File.write(test_image_path, "This is a test image file")

      # Upload to S3
      s3_client = Aws::S3::Client.new(
        region: 'eu-north-1',
        access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
        secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key)
      )

      bucket_name = 'bullet-services'
      key = "test-images/test_#{Time.current.to_i}.jpg"

      s3_client.put_object(
        bucket: bucket_name,
        key: key,
        body: File.read(test_image_path),
        content_type: 'image/jpeg'
      )

      puts "✅ Test image uploaded successfully!"
      puts "  Bucket: #{bucket_name}"
      puts "  Key: #{key}"
      puts "  URL: https://#{bucket_name}.s3.eu-north-1.amazonaws.com/#{key}"

      # Clean up
      File.delete(test_image_path)

    rescue => e
      puts "❌ Test image upload failed: #{e.message}"
    end
  end
end
