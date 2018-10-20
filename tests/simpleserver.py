from bottle import route, request, run
import json
import time

@route('/foo/bar', method='any')
def foobar():
    result = {
        'request_headers': {},
        'request_body': {},
        'time': int(time.time()),
    }

    for key in request.headers:
        result['request_headers'][key] = request.headers.get(key)

    result['request_body'] = request.json
    return json.dumps(result)


run(host='0.0.0.0', port=19000, debug=True)
