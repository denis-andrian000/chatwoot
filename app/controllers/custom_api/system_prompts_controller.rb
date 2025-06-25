# /Data/app/chatwoot/chatwoot-custom/app/controllers/custom_api/system_prompts_controller.rb
class CustomApi::SystemPromptsController < ApplicationController # Keep ApplicationController
  # Skips CSRF protection for this controller for all actions. Use with caution!
  # It's okay for API-only controllers where CSRF tokens aren't naturally sent by clients.
  skip_forgery_protection

  # Define file paths as constants
  SYSTEM_PROMPT_FILE_PATH = Rails.root.join('../chatwoot-ai/prompt/system_prompt').to_s
  ENV_CONFIG_FILE_PATH = Rails.root.join('../chatwoot-ai/.env').to_s
  AI_SERVICE_NAME = 'chatwoot-ai-middleware.service'.freeze # Name of your AI systemd service

  # --- Public Actions ---

  # GET /custom_api/system_prompt
  # Reads and returns the content of the system_prompt file.
  def show
    if File.exist?(SYSTEM_PROMPT_FILE_PATH)
      content = File.read(SYSTEM_PROMPT_FILE_PATH)
      render json: { content: content }
    else
      render json: { error: "System prompt file not found at #{SYSTEM_PROMPT_FILE_PATH}" }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "Error in SystemPromptsController#show: #{e.message}"
    render json: { error: "Failed to read system prompt file: #{e.message}" }, status: :internal_server_error
  end

  # POST /custom_api/system_prompt
  # Overwrites the content of the system_prompt file with the provided data.
  def update
    content = params.require(:content)
    File.write(SYSTEM_PROMPT_FILE_PATH, content)
    render json: { status: 'success', message: 'System prompt updated successfully.' }
  rescue ActionController::ParameterMissing
    render json: { error: 'Missing content parameter' }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error "Error in SystemPromptsController#update (prompt): #{e.message}"
    render json: { error: "Failed to write system prompt file: #{e.message}" }, status: :internal_server_error
  end

  # GET /custom_api/env_config
  # Reads and returns the key-value pairs from the .env file.
  def show_env_config
    if File.exist?(ENV_CONFIG_FILE_PATH)
      env_content = File.read(ENV_CONFIG_FILE_PATH)
      parsed_env = parse_env_file(env_content)
      render json: { content: parsed_env }
    else
      render json: { error: ".env file not found at #{ENV_CONFIG_FILE_PATH}" }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "Error in SystemPromptsController#show_env_config: #{e.message}"
    render json: { error: "Failed to read .env file: #{e.message}" }, status: :internal_server_error
  end

  # POST /custom_api/env_config
  # Updates specific key-value pairs in the .env file while preserving comments and other variables.
  def update_env_config
    allowed_keys = [
      :SKIP_IF_AGENT_ONLINE, :BOT_RESET_STATUS, :ENABLE_FOLLOW_UP,
      :FOLLOW_UP_DELAY_MINUTES, :ENABLE_CLOSE_TICKET,
      :CLOSE_TICKET_DELAY_MINUTES, :HANDOVER_AGENT
    ]

    incoming_updates = params.require(:content).permit(allowed_keys).to_h.symbolize_keys

    original_lines = if File.exist?(ENV_CONFIG_FILE_PATH)
                       File.readlines(ENV_CONFIG_FILE_PATH, chomp: true)
                     else
                       []
                     end

    updated_lines = []

    # Build a hash from original lines for efficient lookup and modification
    # This will contain the current state of env vars, including unmanaged ones
    current_env_map = {}
    original_lines.each do |line|
      match = line.match(/^\s*([A-Z_]+)\s*=(.*)$/) # Also handle unquoted values more robustly
      next unless match

      key = match[1].to_sym
      value = match[2].strip
      current_env_map[key] = value
    end

    # Merge incoming updates, converting values to strings
    incoming_updates.each do |key, value|
      current_env_map[key] = case value
                             when TrueClass then 'true'
                             when FalseClass then 'false'
                             else value.to_s
                             end
    end

    # Now reconstruct the file line by line, maintaining comments and unmanaged vars
    # and replacing values for managed vars
    original_lines.each do |line|
      match = line.match(/^\s*([A-Z_]+)\s*=(.*)$/)
      if match
        key = match[1].to_sym
        updated_lines << if allowed_keys.include?(key)
                           # If it's a managed key and it was updated, use the new value
                           "#{key.to_s.upcase}=#{current_env_map[key]}"
                         else
                           # If it's an unmanaged key, keep its original line
                           line
                         end
      else
        # Preserve comments and blank lines
        updated_lines << line
      end
    end

    # Add any new managed keys that weren't present in the original file
    new_managed_keys_to_add = allowed_keys.select do |k|
      incoming_updates.key?(k) && !original_lines.any? do |l|
        l.strip.start_with?("#{k.to_s.upcase}=")
      end
    end
    new_managed_keys_to_add.each do |key|
      updated_lines << "#{key.to_s.upcase}=#{current_env_map[key]}"
    end

    File.write(ENV_CONFIG_FILE_PATH, updated_lines.uniq.join("\n") + "\n") # .uniq to avoid duplicates if merge logic adds them.
    render json: { status: 'success', message: 'Environment variables updated successfully.' }
  rescue ActionController::ParameterMissing => e
    Rails.logger.error "Error in SystemPromptsController#update_env_config (missing param): #{e.message}"
    render json: { error: 'Missing or invalid content parameter. Ensure correct keys are sent.' }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error "Error in SystemPromptsController#update_env_config: #{e.message}"
    render json: { error: "Failed to write .env file: #{e.message}" }, status: :internal_server_error
  end

  # GET /custom_api/ai_status
  # Checks the status of the AI middleware systemd service.
  def ai_status
    # Use sudo to ensure correct permissions for systemctl status
    status_command = "sudo systemctl status #{AI_SERVICE_NAME}"
    status_output = `#{status_command}` # Execute the command and capture output

    # Parse the output to extract key status information
    status_line = status_output.lines.find { |line| line.strip.start_with?('Active:') }
    if status_line
      status_match = status_line.match(/Active:\s*(?<status>\w+)\s*\((\w+)\)/)
      current_status = status_match ? status_match[:status] : 'unknown'
      render json: { status: current_status, raw_output: status_output }
    else
      render json: { status: 'error', message: 'Could not parse service status.', raw_output: status_output }, status: :internal_server_error
    end
  rescue StandardError => e
    Rails.logger.error "Error in SystemPromptsController#ai_status: #{e.message}"
    render json: { status: 'error', message: "Failed to get AI service status: #{e.message}" }, status: :internal_server_error
  end

  # POST /custom_api/restart_ai
  # Restarts the AI middleware systemd service.
  def restart_ai
    # Use sudo to ensure correct permissions for systemctl restart
    restart_command = "sudo systemctl restart #{AI_SERVICE_NAME}"
    system(restart_command) # Execute the command

    # system returns true for success, false for failure. Wait a moment for service to start.
    # Then re-check status for confirmation.
    sleep 2 # Give service a moment to react

    status_command = "sudo systemctl status #{AI_SERVICE_NAME}"
    status_output = `#{status_command}`
    status_line = status_output.lines.find { |line| line.strip.start_with?('Active:') }

    if status_line && status_line.match(/Active:\s*active\s+\(running\)/)
      render json: { status: 'success', message: 'AI service restarted successfully.' }
    else
      render json: { status: 'failed', message: 'AI service restart failed or did not become active.', raw_output: status_output },
             status: :internal_server_error
    end
  rescue StandardError => e
    Rails.logger.error "Error in SystemPromptsController#restart_ai: #{e.message}"
    render json: { status: 'error', message: "Failed to restart AI service: #{e.message}" }, status: :internal_server_error
  end

  private

  # Helper to parse .env file content into a hash of key-value pairs
  # This version extracts values as strings to match .env file format.
  # It does NOT handle comments or non-key-value lines; it's just for parsing data.
  def parse_env_file(file_content)
    parsed = {}
    file_content.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')

      key, value = line.split('=', 2)
      parsed[key.to_sym] = value.nil? ? '' : value.strip.delete_prefix('"').delete_suffix('"')
    end
    parsed
  end
end
