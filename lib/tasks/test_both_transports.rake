namespace :test do
  desc "Run the Minitest suite against both pgwire and native transports."
  task :both_transports do
    ok = []
    %w[pg native].each do |transport|
      puts "\n=== Running tests over #{transport.upcase} transport ==="
      env = { "NODEDB_TRANSPORT" => transport }
      ok << system(env, "bundle", "exec", "ruby", "bin/rails", "test")
    end

    abort("One or more transports failed.") unless ok.all?
  end
end
