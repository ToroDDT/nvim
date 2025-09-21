vim.api.nvim_create_autocmd('FileType', {
  pattern = 'java',
  callback = function()
    -- Safely require modules
    local ok_jdtls, jdtls = pcall(require, 'jdtls')
    if not ok_jdtls then
      vim.notify('nvim-jdtls not found', vim.log.levels.ERROR)
      return
    end

    local ok_dap, dap = pcall(require, 'dap')
    if not ok_dap then
      vim.notify('nvim-dap not found', vim.log.levels.ERROR)
      return
    end

    -- Locate the java-debug plugin jar
    local bundles = {}
    local debug_jar = vim.fn.glob '~/.local/share/nvim/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar'
    if debug_jar ~= '' then
      table.insert(bundles, debug_jar)
    end

    -- Detect project root
    local root_dir = require('jdtls.setup').find_root { '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' }
    if not root_dir then
      vim.notify('Could not find project root for jdtls', vim.log.levels.WARN)
      return
    end

    -- Start or attach jdtls
    jdtls.start_or_attach {
      cmd = { 'jdtls' },
      root_dir = root_dir,
      init_options = {
        bundles = bundles,
      },
    }

    -- Helper function: compute classpath for Maven projects
    local function get_classpath()
      local handle = io.popen 'mvn dependency:build-classpath -Dmdep.outputFile=/tmp/classpath.txt -q -Dsilent=true'
      if handle then
        handle:close()
      end
      local file = io.open('/tmp/classpath.txt', 'r')
      if not file then
        return {}
      end
      local cp = file:read '*a'
      file:close()
      return vim.split(cp, ':', { plain = true })
    end

    -- Only define once
    if not dap.configurations.java then
      dap.configurations.java = {
        {
          type = 'java',
          request = 'launch',
          name = 'Launch MTG-Mox',
          mainClass = function()
            return vim.fn.input 'Main class > '
          end,
          classPaths = get_classpath(), -- include all Maven dependencies
        },
        {
          type = 'java',
          request = 'attach',
          name = 'Attach to Remote',
          hostName = '127.0.0.1',
          port = 5005,
        },
      }
    end
  end,
})
