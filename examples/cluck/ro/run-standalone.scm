(import scheme
        (chicken base)
        (chicken file)
        (chicken load)
        (chicken process-context)
        (prefix json json:)
        (prefix ncurses nc:)
        (prefix sqlite3 db:))

(begin-for-syntax
  (import (chicken file)
          (chicken process-context))
  (include "src/syntax-bootstrap.scm")
  (include "src/cluck-standalone-prelude.scm"))

(include "src/cluck.scm")

(include "src/cluck/string.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)

(include "src/cluck/fs.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.fs #t)

(include "src/cluck/io.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.io #t)

(include "src/cluck/process.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.process #t)

(define json/json-read json:json-read)
(define json/json-write json:json-write)

(include "examples/cluck/ro/core/cli/cmdspec.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.cli.cmdspec #t)

(include "examples/cluck/ro/core/cli/ro_spec.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.cli.ro-spec #t)

    (include "examples/cluck/ro/core/cli.clk")
    (hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.cli #t)

    (include "examples/cluck/ro/core/cli/completions.clk")
    (hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.cli.completions #t)

(include "examples/cluck/ro/core/commands.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.commands #t)

(include "examples/cluck/ro/core/json.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.json #t)

(include "examples/cluck/ro/core/docs.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.docs #t)

(include "examples/cluck/ro/core/help.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.help #t)

(include "examples/cluck/ro/core/workspace.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.workspace #t)

(include "examples/cluck/ro/core/projects.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.projects #t)

(include "examples/cluck/ro/core/worklog.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.worklog #t)

(include "examples/cluck/ro/core/comments.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.comments #t)

(include "examples/cluck/ro/core/discuss.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.discuss #t)

(include "examples/cluck/ro/core/deps.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.deps #t)

(include "examples/cluck/ro/core/publish.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.publish #t)

(include "examples/cluck/ro/core/capture.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.capture #t)

(include "examples/cluck/ro/core/attachments.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.attachments #t)

(include "examples/cluck/ro/core/clock.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.clock #t)

(include "examples/cluck/ro/core/agenda.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.agenda #t)

(include "examples/cluck/ro/core/outlines.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.outlines #t)

(include "examples/cluck/ro/core/items.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.items #t)

(include "examples/cluck/ro/core/events.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.events #t)

(include "examples/cluck/ro/core/agent.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.agent #t)

(include "examples/cluck/ro/core/sync.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.sync #t)

(include "examples/cluck/ro/core/doctor.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.doctor #t)

(include "examples/cluck/ro/core/reindex.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.reindex #t)

(include "examples/cluck/ro/core/route.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.core.route #t)

(include "examples/cluck/ro/bootstrap-core-aliases.scm")

(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.ro.app #t)

(define nc/A_BOLD nc:A_BOLD)
(define nc/A_REVERSE nc:A_REVERSE)
(define nc/KEY_BACKSPACE nc:KEY_BACKSPACE)
(define nc/KEY_DC nc:KEY_DC)
(define nc/KEY_DOWN nc:KEY_DOWN)
(define nc/KEY_END nc:KEY_END)
(define nc/KEY_ENTER nc:KEY_ENTER)
(define nc/KEY_HOME nc:KEY_HOME)
(define nc/KEY_LEFT nc:KEY_LEFT)
(define nc/KEY_NPAGE nc:KEY_NPAGE)
(define nc/KEY_PPAGE nc:KEY_PPAGE)
(define nc/KEY_RESIZE nc:KEY_RESIZE)
(define nc/KEY_RIGHT nc:KEY_RIGHT)
(define nc/KEY_UP nc:KEY_UP)
(define nc/attroff nc:attroff)
(define nc/attron nc:attron)
(define nc/cbreak nc:cbreak)
(define nc/curs_set nc:curs_set)
(define nc/endwin nc:endwin)
(define nc/erase nc:erase)
(define nc/getch nc:getch)
(define nc/getmaxyx nc:getmaxyx)
(define nc/initscr nc:initscr)
(define nc/keyname nc:keyname)
(define nc/keypad nc:keypad)
(define nc/move nc:move)
(define nc/mvaddstr nc:mvaddstr)
(define nc/noecho nc:noecho)
(define nc/refresh nc:refresh)
(define nc/stdscr nc:stdscr)

(define db/execute db:execute)
(define db/finalize! db:finalize!)
(define db/first-result db:first-result)
(define db/last-insert-rowid db:last-insert-rowid)
(define db/make-busy-timeout db:make-busy-timeout)
(define db/map-row db:map-row)
(define db/open-database db:open-database)
(define db/set-busy-handler! db:set-busy-handler!)
(define db/update db:update)
(define db/with-transaction db:with-transaction)

(include "examples/cluck/ro/src/app.clk")
(include "examples/cluck/ro/main.clk")

(let ((args (command-line-arguments)))
  (let ((result (main args)))
    (if (number? result)
        (exit result)
        (if (and (pair? args)
                 (string=? (car args) "completion")
                 (null? (cdr args)))
            (exit 1)
            #t))))
