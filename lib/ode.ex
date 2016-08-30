defmodule Ode do
  @auth_url     "https://login.live.com/oauth20_authorize.srf"
  @token_url    "https://login.live.com/oauth20_token.srf"
  @redirect_uri "https://login.live.com/oauth20_desktop.srf"

  @client_id    "7ee18b85-8a43-4fe0-9a44-1b965038d3d4"

  @config_file_path "./config.json"
  @refresh_token_path "./token.json"


  def main(args \\ []) do

    args
    |> parse_args
    |> process

    read_config

    read_token
  end

  def parse_args(args) do
    options =
      args
      |> OptionParser.parse()
    elem(options, 0)
  end

  def process([]) do
    IO.puts "No arguments"
  end

  def process(options) do
    case hd options do
      {:debug, true} -> IO.puts "debug"
      {:monitor, true} -> IO.puts "monitor"
      _ -> IO.puts "another"
    end
    process (tl options)
  end

  def read_config() do
    case File.read(@config_file_path) do
      {:ok, body} -> IO.puts body
      {:error, reason} -> IO.puts reason
    end
  end

  def read_token do
    case File.read(@refresh_token_path) do
      {:ok, body} ->
        body
      {:error, _} ->
        authorize
    end
  end

  def authorize() do
    auth_url_full = @auth_url
    <> "?client_id=" <> @client_id
    <> "&scope=onedrive.readwrite%20offline_access"
    <> "&response_type=code"
    <> "&redirect_uri=" <>@redirect_uri

    IO.puts "Autorize this app visiging:"
    IO.puts auth_url_full
    response = IO.gets "enter the response uri:"

    String.trim(response)
    |> get_code
  end

  def get_code(response_uri) do
    Regex.run(~r/(?:code=)(([\w\d]+-){4}[\w\d]+)/,response_uri)
    |> tl
    |> hd
    |> validate_code
  end

  def validate_code(code) do
    case String.length(code) do
      0 -> IO.puts "empty"
      _ -> redeem_token(code)
    end
  end

  defmodule OneDrive do
    use HTTPoison.Base

    def process_url(url) do
      url
    end

    def process_request_body(body) do
      body
    end

    def process_request_headers(headers) when is_map(headers) do
      Enum.into(headers, [])
    end
  end

  def redeem_token(code) do
    body = "client_id=" <> @client_id
    <> "&redirect_uri=" <> @redirect_uri
    <> "&code=" <> code
    <> "&grant_type=authorization_code"
    header = %{"Content-Type": "application/x-www-form-urlencoded"}

    case OneDrive.post(@token_url, body, header) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        aquire_token(body)
      {:ok, %HTTPoison.Response{status_code: 400}} ->
        IO.puts "failed."
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
    end
  end

  def aquire_token(body) do
    tokens = Poison.decode!(body)

    access_token = tokens["token_type"] <> " " <> tokens["access_token"]
    refresh_token = tokens["refresh_token"]
    access_token_expiration = :os.system_time(:seconds) + tokens["expires_in"]

    token_path = Path.absname(@refresh_token_path)
    File.write(token_path, refresh_token, :line)
  end
end
