require 'aws-sdk'

PROFILES = %w()
REGIONS = %w(us-east-1 us-west-1 us-west-2)

def get_statuses(client)
  results = client.describe_instance_status(filters: [ { name: 'event.code', values: ['system-reboot'] } ])[:instance_statuses]
  results.map { |i| [i.instance_id, i.events[0].not_before] }
end

def add_names(client, results)
  instances = client.describe_instances(instance_ids: results.map(&:first))[:reservations].map(&:instances).flatten
  instances.each do |instance|
    r = results.find { |r| r[0] == instance.instance_id }
    r << instance.tags.find { |t| t.key == 'Name' }.value
  end
  return results
end


PROFILES.each do |profile|
  begin
    credentials = Aws::SharedCredentials.new(profile_name: profile)
    puts "Checking #{profile}:"
    REGIONS.each do |region|
      puts "  Region: #{region}"
      client = Aws::EC2::Client.new(credentials: credentials, region: region)

      results = get_statuses(client)

      if results.empty?
        puts "    -"
      else
        results = add_names(client, results)
        results.each do |r|
          puts "    #{r[2]}  #{r[1].strftime('%e %b %Y %H:%M:%S%p')}"
        end
      end

    end
  rescue Aws::Errors::NoSuchProfileError
  end
end
