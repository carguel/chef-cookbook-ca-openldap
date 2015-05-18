action :merge do
  new_resource.options.each do |k, v|
    if v == "::delete::"
      @config_options.delete(k)
    else
      @config_options.set(k, v)
    end
  end

  if new_resource.options != current_resource.options
    converge_by("merge_options_into_slapd_general_configuration") do
      updated = @config_options.save
    end
    new_resource.updated_by_last_action(true)
  else
    new_resource.updated_by_last_action(false)
  end

end

def load_current_resource
  @current_resource = Chef::Resource::CaOpenldapGeneralConfiguration.new(@new_resource.name)
  @config_options = CaOpenldap::GlobalConfigOptions.new()

  current_options = @config_options.options.clone
  current_options.delete_if do |k|
    ! @new_resource.options.has_key? k
  end 

  # Add the keys to delete if they are already not included 
  # in current options.
  # This is to ensure detection of uptodate resource.
  new_resource.options.each do |k, v|
    if v == "::delete::" && ! current_options.has_key?(k)
      current_options[k] = v 
    end
  end

  @current_resource.options current_options
  @current_resource
end

def whyrun_supported?
  true
end
