"""python -m pdf2excel : 인자가 있으면 CLI, 없으면 GUI 실행."""
import sys

if len(sys.argv) > 1:
    from .cli import main
    sys.exit(main())
else:
    from .gui import main
    main()
