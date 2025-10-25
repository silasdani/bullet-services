# frozen_string_literal: true

namespace :user do
  desc 'Create or update a superadmin user'
  task :create_superadmin, %i[email password] => :environment do |_, args|
    email = args[:email] || ENV.fetch('EMAIL', nil)
    password = args[:password] || ENV.fetch('PASSWORD', nil)

    unless email && password
      puts 'Usage: rake user:create_superadmin[email,password] or EMAIL=... PASSWORD=... rake user:create_superadmin'
      exit 1
    end

    user = User.with_deleted.find_or_initialize_by(email: email)
    user.password = password
    user.password_confirmation = password
    user.role = :super_admin
    user.confirmed_at ||= Time.current
    user.deleted_at = nil
    user.webflow_access = true
    user.save!
    puts "Superadmin ensured: #{user.email} (id=#{user.id})"
  end
end
