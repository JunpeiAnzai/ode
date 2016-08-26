defmodule Ode do
  def main(args \\ []) do
    config_file_path = "./config.json"

    args
    |> parse_args
    |> process

    config_file_path
    |> read_config

    authentication
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

  def read_config(path) do
    case File.read(path) do
      {:ok, body} -> IO.puts body
      {:error, reason} -> IO.puts reason
    end
  end

  def authentication() do
    auth_url = "https://login.live.com/oauth20_authorize.srf"
    token_url = "https://login.live.com/oauth20_token.srf"
    client_id = "7ee18b85-8a43-4fe0-9a44-1b965038d3d4"
    redirect_url = "https://login.live.com/oauth20_desktop.srf"
    auth_url_full = auth_url
    <> "?client_id="
    <> client_id
    <> "&scope=onedrive.readwrite%20offline_access&response_type=code&redirect_uri="
    <> redirect_url

    IO.puts "Autorize this app visiging:\n"
    IO.puts auth_url_full
    response = IO.gets "enter the response uri:"

    String.trim(response)
    |> get_code
  end

  def get_code(response_uri) do
    c = Regex.run(~r/(?:code=)(([\w\d]+-){4}[\w\d]+)/,
      response_uri)
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
      "https://login.live.com/oauth20_token.srf"
    end

    def process_request_body(body) do
      body
    end

    def process_request_headers(headers) when is_map(headers) do
      Enum.into(headers, [])
    end
  end

  def redeem_token(code) do
    token_url = "https://login.live.com/oauth20_token.srf"
    redirect_url = "https://login.live.com/oauth20_desktop.srf"
    client_id = "7ee18b85-8a43-4fe0-9a44-1b965038d3d4"
    client_secret = "z2Me1OSNiAa5snEwyZcMDFG"
    body = "client_id=" <> client_id
    <> "&redirect_uri=" <> redirect_url
    #<> "&client_secret=" <> client_secret
    <> "&code=" <> code
    <> "&grant_type=authorization_code"
    header = %{"Content-Type": "application/x-www-form-urlencoded"}

    OneDrive.start
    OneDrive.process_request_body(body)
    OneDrive.process_request_headers(header)
    #response = OneDrive.post(token_url, body, header)
    response = HTTPoison.post!(token_url, body, header, [])
    IO.puts inspect response
  end
end
